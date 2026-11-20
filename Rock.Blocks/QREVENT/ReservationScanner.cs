using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Runtime.Caching;
using System.Web;

using Rock;
using Rock.Attribute;
using Rock.Blocks;
using Rock.Data;
using Rock.Model;
using Rock.Security;

namespace Rock.Blocks.QREVENT
{
    [DisplayName( "Reservation Scanner" )]
    [Category( "Check-in > Sunday Service" )]
    [Description( "Escanea codigos QR de reservaciones de Sunday Service y marca asistencia (Obsidian)." )]

    #region Block Attributes

    [IntegerField(
        "Campus Id",
        Description = "El ID del campus para filtrar los slots disponibles.",
        IsRequired = true,
        DefaultIntegerValue = 0,
        Order = 0,
        Key = AttributeKey.CampusId )]

    [TextField(
        "Allowed Schedule Ids",
        Description = "Lista de ScheduleIds permitidos, separados por coma (ej: 7,9,11,13,18).",
        IsRequired = true,
        DefaultValue = "",
        Order = 1,
        Key = AttributeKey.AllowedScheduleIds )]

    #endregion

    public class ReservationScanner : RockBlockType
    {
        // Ventana de check-in de cada cupo: abre A minutos ANTES de la hora de inicio
        // del servicio y cierra C minutos DESPUES de esa misma hora.
        // ( 2026-09-05: la apertura paso de 10 a 15 min a pedido del ministerio. )
        // ( 2026-11-20: A y C son configurables POR CUPO desde Configuracion Domingos,
        //   columnas SundayServiceSlot.CheckInOpensMinutesBefore / CheckInClosesMinutesAfter;
        //   NULL = 15 / 80, los valores de siempre. Valores y deteccion de las columnas en
        //   SundayServiceCapacityAdmin. )
        //
        // Deliberadamente no se usa el DTEND del iCal para cerrar ( ver historia en
        // Rock.Blocks/QREVENT/CHANGES.md ). El cierre de la puerta es el MISMO valor que usa
        // SundayServiceRegistration para dejar de aceptar reservas de ese cupo: asi todo lo
        // que la app deja reservar sigue siendo escaneable en la puerta.
        //
        // Ventanas que se cruzan: hasta 2026-11-20 el escaner elegia UN cupo "activo" y
        // sp_SundayServiceCheckIn rechazaba ( -2 ) las reservas de cualquier otro, asi que
        // dos ventanas cruzadas rechazaban en la puerta a gente con reserva valida. Desde
        // entonces cada QR se valida contra la ventana de SU propio cupo ( ver
        // ResolveReservationSlot ) y el cupo "activo" solo sirve para el encabezado.

        private const int InvalidScanThrottleWindowSeconds = 10;
        private const int InvalidScanThrottleLimit = 60;
        private static readonly ObjectCache ScanThrottleCache = MemoryCache.Default;
        private static readonly object ScanThrottleLock = new object();

        #region Attribute Keys

        private static class AttributeKey
        {
            public const string CampusId = "CampusId";
            public const string AllowedScheduleIds = "AllowedScheduleIds";
        }

        #endregion

        #region Block Initialization

        /// <summary>
        /// Hora del servidor en el mismo formato sin zona que <c>CheckInStartIso</c>.
        /// El cliente calcula con ella el desfase de su propio reloj: el contador de
        /// "Abre en ..." corria con la hora del dispositivo, asi que cada escaner abria
        /// en un instante distinto segun como anduviera su reloj. Al venir los dos ISO
        /// con la misma convencion, el offset absorbe tanto la deriva del reloj como una
        /// diferencia de zona horaria.
        /// </summary>
        private static string ServerNowIso()
        {
            return RockDateTime.Now.ToString( "yyyy-MM-ddTHH:mm:ss" );
        }

        public override object GetObsidianBlockInitialization()
        {
            var kioskId = PageParameter( "KioskId" ).AsIntegerOrNull()
                ?? PageParameter( "kioskId" ).AsIntegerOrNull()
                ?? PageParameter( "Kiosk" ).AsIntegerOrNull()
                ?? PageParameter( "kiosk" ).AsIntegerOrNull();

            if ( !IsScannerOperatorAuthorized() )
            {
                return new InitBag
                {
                    activeSlot = null,
                    nextScheduleInfo = "No autorizado para usar este escaner.",
                    nextCheckInStartIso = null,
                    serverNowIso = ServerNowIso(),
                    kioskId = kioskId
                };
            }

            var slotResult = GetActiveSlotInternal();

            return new InitBag
            {
                activeSlot = slotResult.Slot,
                nextScheduleInfo = slotResult.NextScheduleInfo,
                nextCheckInStartIso = slotResult.NextCheckInStartIso,
                serverNowIso = ServerNowIso(),
                kioskId = kioskId
            };
        }

        #endregion

        #region Block Actions

        [BlockAction( "GetActiveSlot" )]
        public BlockActionResult GetActiveSlot()
        {
            if ( !IsScannerOperatorAuthorized() )
            {
                return ActionForbidden( "No autorizado para usar este escaner." );
            }

            var slotResult = GetActiveSlotInternal();

            return ActionOk( new
            {
                activeSlot = slotResult.Slot,
                nextScheduleInfo = slotResult.NextScheduleInfo,
                nextCheckInStartIso = slotResult.NextCheckInStartIso,
                serverNowIso = ServerNowIso()
            } );
        }

        [BlockAction( "ProcessScan" )]
        public BlockActionResult ProcessScan( ProcessScanRequestBag bag )
        {
            if ( !IsScannerOperatorAuthorized() )
            {
                return ActionForbidden( "No autorizado para registrar asistencia." );
            }

            if ( IsInvalidScanThrottled() )
            {
                return ActionOk( BuildGenericDeniedResult( "error", "Demasiados intentos invalidos. Espera unos segundos." ) );
            }

            if ( bag == null || string.IsNullOrWhiteSpace( bag.reservationCode ) )
            {
                RegisterInvalidScanAttempt();
                return ActionOk( BuildGenericDeniedResult() );
            }

            var reservationCode = bag.reservationCode.Trim();
            if ( reservationCode.Length == 0 || reservationCode.Length > 10 )
            {
                RegisterInvalidScanAttempt();
                return ActionOk( BuildGenericDeniedResult() );
            }

            var campusId = GetAttributeValue( AttributeKey.CampusId ).AsInteger();
            var allowedScheduleIds = ParseCsvInts( GetAttributeValue( AttributeKey.AllowedScheduleIds ) );

            if ( campusId == 0 || allowedScheduleIds.Count == 0 )
            {
                return ActionOk( BuildResult( "error", "", "Configura el bloque correctamente (CampusId y AllowedScheduleIds).", null, 0 ) );
            }

            try
            {
                using ( var rockContext = new RockContext() )
                {
                    // Cada QR se valida contra la ventana de SU propio cupo (2026-11-20). Antes se
                    // comparaba contra un unico cupo "activo" y, si dos ventanas se cruzaban, la
                    // puerta rechazaba reservas validas del otro servicio.
                    var target = ResolveReservationSlot( rockContext, reservationCode, campusId, allowedScheduleIds );

                    if ( target == null )
                    {
                        // Codigo inexistente: mismo mensaje generico de siempre.
                        RegisterInvalidScanAttempt();
                        return ActionOk( BuildGenericDeniedResult() );
                    }

                    var now = GuatemalaNow();

                    if ( !target.InScope || !target.IsActive || target.OccurrenceDate.Date != now.Date )
                    {
                        // Otra sede, un horario que esta puerta no recibe, un cupo desactivado u
                        // otro dia. No revela de que horario es ni de quien.
                        RegisterInvalidScanAttempt();
                        var msg = target.InScope && target.IsActive
                            ? "Esta reserva no es para hoy."
                            : "Esta reserva es de otro horario.";
                        return ActionOk( BuildResult( "other_schedule", "", msg, null, 0 ) );
                    }

                    var serviceTime = ExtractTimeFromICal( target.iCalendarContent );
                    if ( serviceTime.HasValue )
                    {
                        // Sin hora legible no hay ventana con que comparar: se deja pasar al SP
                        // (mismo criterio fail-open que el corte de la reserva).
                        var serviceDateTime = now.Date.Add( serviceTime.Value );
                        var opensAt = serviceDateTime.AddMinutes( -target.DoorOpensMinutes );
                        var closesAt = serviceDateTime.AddMinutes( target.DoorClosesMinutes );

                        // Llegar temprano o tarde con una reserva real no es un intento invalido:
                        // no cuenta para el throttle.
                        if ( now < opensAt )
                        {
                            return ActionOk( BuildResult( "other_schedule", "",
                                $"Esta reserva es del servicio de las {serviceDateTime:HH:mm}. La puerta abre a las {opensAt:HH:mm}.", null, 0 ) );
                        }

                        if ( now > closesAt )
                        {
                            return ActionOk( BuildResult( "other_schedule", "",
                                $"El ingreso para el servicio de las {serviceDateTime:HH:mm} cerró a las {closesAt:HH:mm}.", null, 0 ) );
                        }
                    }

                    var currentPersonAliasId = ( int? ) new PersonAliasService( rockContext )
                        .GetPrimaryAliasId( RequestContext.CurrentPerson.Id );

                    // El check-in vive en sp_SundayServiceCheckIn para respetar el orden de
                    // locks del modulo (Slot -> Reservation). Cuando el UPDATE se hacia aqui
                    // suelto entraba por la PK y hacia deadlock contra
                    // sp_SundayServiceReservationConfirm, que entra por IX_...SlotPersonStatus:
                    // el escaner siempre era la victima. Ver encabezado v3 de
                    // Dev Tools/Sql/QREVENT_SundayService_Hardening.sql.
                    var sql = @"
EXEC dbo.sp_SundayServiceCheckIn
    @ReservationCode,
    @ActiveSlotId,
    @ScannerAliasId";

                    var pCode = new SqlParameter( "@ReservationCode", reservationCode );
                    // El SP sigue exigiendo que la reserva sea del cupo indicado: se le pasa el
                    // cupo de la propia reserva, ya validado arriba. Si entre la lectura y el SP
                    // la reserva cambiara de cupo, el SP devuelve -2 y se rechaza igual que antes.
                    var pSlot = new SqlParameter( "@ActiveSlotId", target.SlotId );
                    var pScanner = new SqlParameter( "@ScannerAliasId", ( object ) currentPersonAliasId ?? DBNull.Value );

                    var row = rockContext.Database
                        .SqlQuery<CheckInResultRow>( sql, pCode, pSlot, pScanner )
                        .FirstOrDefault();

                    if ( row == null )
                    {
                        return ActionOk( BuildResult( "error", "", "Error al procesar el codigo.", null, 0 ) );
                    }

                    // 0 = ya tenia check-in. Respuesta legitima, no un intento invalido.
                    if ( row.ResultCode == 0 )
                    {
                        return ActionOk( BuildAlreadyProcessedResult() );
                    }

                    if ( row.ResultCode != 1 )
                    {
                        if ( row.ResultCode == -99 )
                        {
                            return ActionOk( BuildResult( "error", "", "Error al procesar el codigo.", null, 0 ) );
                        }

                        // Cuenta como intento fallido para el throttle en todos los casos.
                        RegisterInvalidScanAttempt();

                        // -2 = la reserva existe pero pertenece a otro horario. El
                        // operador necesita distinguirla de un QR inventado para poder
                        // resolverlo en la puerta; no se revela de que horario es ni de
                        // quien, solo que el codigo no corresponde a este servicio.
                        if ( row.ResultCode == -2 )
                        {
                            return ActionOk( BuildResult( "other_schedule", "", "Esta reserva es de otro horario.", null, 0 ) );
                        }

                        // -1 codigo inexistente, -3 cancelada/no-show: mensaje generico,
                        // sin revelar el motivo.
                        return ActionOk( BuildGenericDeniedResult() );
                    }

                    ClearInvalidScanAttempts();

                    var personName = GetReservationPersonName( rockContext, row.PersonAliasId, row.PersonId );

                    // Aviso al telefono de la persona (su pagina de reserva, abierta en el
                    // WebView mostrando el QR). Solo aqui, con check-in real: el 0 (ya tenia
                    // check-in) y los rechazos no avisan. Fire-and-forget: no espera ni falla.
                    SundayServiceTopic.NotifyReservationCheckedIn(
                        reservationCode,
                        personName,
                        target.ScheduleName,
                        row.Quantity ?? 0 );

                    return ActionOk( BuildResult( "checked_in", personName, "Asistencia marcada correctamente.", target.ScheduleName, row.Quantity ?? 0 ) );
                }
            }
            catch ( Exception ex )
            {
                ExceptionLogService.LogException( ex );
                return ActionOk( BuildResult( "error", "", "Error al procesar el codigo.", null, 0 ) );
            }
        }

        #endregion

        #region Private Methods

        private bool IsScannerOperatorAuthorized()
        {
            var currentPerson = RequestContext?.CurrentPerson;
            return currentPerson != null && BlockCache.IsAuthorized( Authorization.EDIT, currentPerson );
        }

        private string GetInvalidScanThrottleKey()
        {
            var personId = RequestContext?.CurrentPerson?.Id ?? 0;
            var remoteAddress = HttpContext.Current?.Request?.UserHostAddress ?? "unknown";

            return $"SundayServiceReservationScanner:{personId}:{remoteAddress}";
        }

        private bool IsInvalidScanThrottled()
        {
            var key = GetInvalidScanThrottleKey();
            var now = DateTime.UtcNow;

            lock ( ScanThrottleLock )
            {
                var state = ScanThrottleCache.Get( key ) as InvalidScanThrottleState;
                return state != null && state.BlockUntilUtc.HasValue && state.BlockUntilUtc.Value > now;
            }
        }

        private void RegisterInvalidScanAttempt()
        {
            var key = GetInvalidScanThrottleKey();
            var now = DateTime.UtcNow;

            lock ( ScanThrottleLock )
            {
                var state = ScanThrottleCache.Get( key ) as InvalidScanThrottleState;

                if ( state == null || now - state.WindowStartUtc >= TimeSpan.FromSeconds( InvalidScanThrottleWindowSeconds ) )
                {
                    state = new InvalidScanThrottleState
                    {
                        Count = 0,
                        WindowStartUtc = now,
                        BlockUntilUtc = null
                    };
                }

                state.Count++;

                if ( state.Count >= InvalidScanThrottleLimit )
                {
                    state.BlockUntilUtc = now.AddSeconds( InvalidScanThrottleWindowSeconds );
                }

                ScanThrottleCache.Set(
                    key,
                    state,
                    new CacheItemPolicy
                    {
                        AbsoluteExpiration = DateTimeOffset.UtcNow.AddMinutes( 2 )
                    } );
            }
        }

        private void ClearInvalidScanAttempts()
        {
            var key = GetInvalidScanThrottleKey();

            lock ( ScanThrottleLock )
            {
                if ( ScanThrottleCache.Contains( key ) )
                {
                    ScanThrottleCache.Remove( key );
                }
            }
        }

        private static object BuildGenericDeniedResult( string status = "invalid_qr", string message = "El QR no es valido para este ingreso." )
        {
            return BuildResult( status, "", message, null, 0 );
        }

        private static object BuildAlreadyProcessedResult()
        {
            return BuildResult( "already_used", "", "Este QR ya fue procesado.", null, 0 );
        }

        private ActiveSlotResult GetActiveSlotInternal()
        {
            int campusId = GetAttributeValue( AttributeKey.CampusId ).AsInteger();
            var allowedScheduleIds = ParseCsvInts( GetAttributeValue( AttributeKey.AllowedScheduleIds ) );

            if ( campusId == 0 || allowedScheduleIds.Count == 0 )
            {
                return new ActiveSlotResult
                {
                    Slot = null,
                    NextScheduleInfo = "Configura el bloque correctamente (CampusId y AllowedScheduleIds)."
                };
            }

            var gtZone = TimeZoneInfo.FindSystemTimeZoneById( "Central America Standard Time" );
            var now = TimeZoneInfo.ConvertTimeFromUtc( DateTime.UtcNow, gtZone );
            var today = now.Date;

            using ( var rockContext = new RockContext() )
            {
                var sql = @"
SELECT TOP 10
    slot.Id AS SlotId,
    slot.ScheduleId,
    slot.OccurrenceDate,
    sch.Name AS ScheduleName,
    sch.iCalendarContent,
    " + SundayServiceCapacityAdmin.DoorOpensSqlExpression( rockContext, "slot" ) + @" AS DoorOpensMinutes,
    " + SundayServiceCapacityAdmin.DoorClosesSqlExpression( rockContext, "slot" ) + @" AS DoorClosesMinutes
FROM dbo.SundayServiceSlot slot
INNER JOIN dbo.Schedule sch ON sch.Id = slot.ScheduleId
WHERE slot.CampusId = @CampusId
  AND slot.OccurrenceDate = @Today
  AND slot.IsActive = 1
  AND " + BuildScheduleFilter( allowedScheduleIds ) + @"
ORDER BY sch.Id
";

                var slots = rockContext.Database.SqlQuery<SlotScheduleInfo>(
                    sql,
                    new SqlParameter( "@CampusId", campusId ),
                    new SqlParameter( "@Today", today ),
                    new SqlParameter( "@SpecialGuid", new Guid( SundayServiceCapacityAdmin.SpecialServiceCategoryGuid ) )
                ).ToList();

                // Cupos con la puerta abierta ahora (cada uno con SU apertura). Puede haber
                // mas de uno si sus ventanas se cruzan: el escaneo valida cada QR contra su
                // propio cupo, asi que aqui solo se arma el encabezado. El cupo de referencia
                // es el de hora de inicio mas cercana a "ahora".
                var openSlots = new List<Tuple<SlotScheduleInfo, DateTime>>();

                foreach ( var slot in slots )
                {
                    var serviceTime = ExtractTimeFromICal( slot.iCalendarContent );
                    if ( !serviceTime.HasValue )
                    {
                        continue;
                    }

                    var serviceDateTime = today.Add( serviceTime.Value );
                    if ( IsDoorOpen( serviceDateTime, slot.DoorOpensMinutes, slot.DoorClosesMinutes, now ) )
                    {
                        openSlots.Add( Tuple.Create( slot, serviceDateTime ) );
                    }
                }

                if ( openSlots.Count > 0 )
                {
                    var ordered = openSlots.OrderBy( x => x.Item2 ).ToList();
                    var best = openSlots.OrderBy( x => Math.Abs( ( now - x.Item2 ).Ticks ) ).First();

                    return new ActiveSlotResult
                    {
                        Slot = new ActiveSlotBag
                        {
                            slotId = best.Item1.SlotId,
                            scheduleId = best.Item1.ScheduleId,
                            // Con dos o mas abiertos, el encabezado los nombra a todos para que
                            // el operador sepa que la puerta recibe a ambos.
                            scheduleName = ordered.Count == 1
                                ? best.Item1.ScheduleName
                                : string.Join( " + ", ordered.Select( x => x.Item1.ScheduleName ) ),
                            occurrenceTime = best.Item2.ToString( "HH:mm" )
                        },
                        NextScheduleInfo = null
                    };
                }

                var nextResult = GetNextScheduleInfo( rockContext, campusId, allowedScheduleIds, now, today );

                return new ActiveSlotResult
                {
                    Slot = null,
                    NextScheduleInfo = nextResult.Info,
                    NextCheckInStartIso = nextResult.CheckInStartIso
                };
            }
        }

        private class NextScheduleResult
        {
            public string Info { get; set; }
            public string CheckInStartIso { get; set; }
        }

        private NextScheduleResult GetNextScheduleInfo( RockContext rockContext, int campusId, List<int> allowedScheduleIds, DateTime now, DateTime today )
        {
            var sql = @"
SELECT TOP 10
    slot.Id AS SlotId,
    slot.ScheduleId,
    sch.Name AS ScheduleName,
    slot.OccurrenceDate,
    sch.iCalendarContent,
    " + SundayServiceCapacityAdmin.DoorOpensSqlExpression( rockContext, "slot" ) + @" AS DoorOpensMinutes,
    " + SundayServiceCapacityAdmin.DoorClosesSqlExpression( rockContext, "slot" ) + @" AS DoorClosesMinutes
FROM dbo.SundayServiceSlot slot
INNER JOIN dbo.Schedule sch ON sch.Id = slot.ScheduleId
WHERE slot.CampusId = @CampusId
  AND slot.OccurrenceDate >= @Today
  AND slot.IsActive = 1
  AND " + BuildScheduleFilter( allowedScheduleIds ) + @"
ORDER BY slot.OccurrenceDate, sch.Id
";

            var nextSlots = rockContext.Database.SqlQuery<SlotScheduleInfo>(
                sql,
                new SqlParameter( "@CampusId", campusId ),
                new SqlParameter( "@Today", today ),
                new SqlParameter( "@SpecialGuid", new Guid( SundayServiceCapacityAdmin.SpecialServiceCategoryGuid ) )
            ).ToList();

            // El ORDER BY de SQL es por (OccurrenceDate, sch.Id) y la hora real vive
            // dentro del iCalendar, no en una columna: ordenar por Id anunciaba como
            // "proximo" un horario posterior cuando los ScheduleIds no seguian el
            // orden cronologico. Se ordena aqui, ya con la hora resuelta.
            var upcoming = nextSlots
                .Select( slot => new
                {
                    slot.ScheduleName,
                    slot.OccurrenceDate,
                    slot.DoorOpensMinutes,
                    ServiceTime = ExtractTimeFromICal( slot.iCalendarContent )
                } )
                .Where( x => x.ServiceTime.HasValue )
                .Select( x => new
                {
                    x.ScheduleName,
                    ServiceDateTime = x.OccurrenceDate.Add( x.ServiceTime.Value ),
                    DoorOpensAt = x.OccurrenceDate.Add( x.ServiceTime.Value ).AddMinutes( -x.DoorOpensMinutes )
                } )
                .Where( x => x.DoorOpensAt > now )
                // El proximo es el que ABRE primero la puerta, no el que empieza primero: con
                // aperturas distintas por cupo no siempre coinciden.
                .OrderBy( x => x.DoorOpensAt )
                .FirstOrDefault();

            if ( upcoming != null )
            {
                var esGt = new CultureInfo( "es-GT" );
                var checkInStart = upcoming.DoorOpensAt;

                return new NextScheduleResult
                {
                    Info = string.Format( "Proximo: {0} - {1}",
                        upcoming.ScheduleName, upcoming.ServiceDateTime.ToString( "dddd dd/MM HH:mm", esGt ) ),
                    CheckInStartIso = checkInStart.ToString( "yyyy-MM-ddTHH:mm:ss" )
                };
            }

            return new NextScheduleResult
            {
                Info = "No hay horarios programados proximamente.",
                CheckInStartIso = null
            };
        }

        /// <summary>
        /// Filtro de horarios del escáner: los del atributo «Allowed Schedule Ids» más los
        /// servicios especiales creados desde Configuración Domingos (categoría
        /// <see cref="SundayServiceCapacityAdmin.SpecialServiceCategoryGuid"/>, parámetro
        /// <c>@SpecialGuid</c>). Así un servicio especial no obliga a editar este bloque.
        /// Los Ids vienen de <see cref="ParseCsvInts"/> (solo enteros positivos).
        /// </summary>
        /// <summary>
        /// Cupo de la reserva con el código dado, con sus datos de ventana y si esta puerta lo
        /// recibe (misma sede y horario permitido o especial). Lectura sin lock: el SP vuelve a
        /// validar bajo lock. null si el código no existe.
        /// </summary>
        private static ReservationSlotInfo ResolveReservationSlot( RockContext rockContext, string reservationCode, int campusId, List<int> allowedScheduleIds )
        {
            var sql = @"
SELECT TOP 1
    slot.Id AS SlotId,
    slot.OccurrenceDate,
    slot.IsActive,
    sch.Name AS ScheduleName,
    sch.iCalendarContent,
    " + SundayServiceCapacityAdmin.DoorOpensSqlExpression( rockContext, "slot" ) + @" AS DoorOpensMinutes,
    " + SundayServiceCapacityAdmin.DoorClosesSqlExpression( rockContext, "slot" ) + @" AS DoorClosesMinutes,
    CAST( CASE WHEN slot.CampusId = @CampusId AND " + BuildScheduleFilter( allowedScheduleIds ) + @" THEN 1 ELSE 0 END AS bit ) AS InScope
FROM dbo.SundayServiceReservation r
INNER JOIN dbo.SundayServiceSlot slot ON slot.Id = r.SlotId
INNER JOIN dbo.Schedule sch ON sch.Id = slot.ScheduleId
WHERE r.ReservationCode = @ReservationCode";

            return rockContext.Database.SqlQuery<ReservationSlotInfo>(
                sql,
                new SqlParameter( "@ReservationCode", reservationCode ),
                new SqlParameter( "@CampusId", campusId ),
                new SqlParameter( "@SpecialGuid", new Guid( SundayServiceCapacityAdmin.SpecialServiceCategoryGuid ) )
            ).FirstOrDefault();
        }

        /// <summary>¿La puerta acepta QR de un servicio que empieza en <paramref name="serviceDateTime"/>?</summary>
        private static bool IsDoorOpen( DateTime serviceDateTime, int doorOpensMinutes, int doorClosesMinutes, DateTime now )
        {
            return now >= serviceDateTime.AddMinutes( -doorOpensMinutes )
                && now <= serviceDateTime.AddMinutes( doorClosesMinutes );
        }

        private static DateTime GuatemalaNow()
        {
            var gtZone = TimeZoneInfo.FindSystemTimeZoneById( "Central America Standard Time" );
            return TimeZoneInfo.ConvertTimeFromUtc( DateTime.UtcNow, gtZone );
        }

        private static string BuildScheduleFilter( List<int> allowedScheduleIds )
        {
            return "( slot.ScheduleId IN (" + string.Join( ",", allowedScheduleIds ) + ")"
                + " OR sch.CategoryId IN ( SELECT c.Id FROM dbo.Category c WHERE c.[Guid] = @SpecialGuid ) )";
        }

        private static TimeSpan? ExtractTimeFromICal( string iCal )
        {
            return ExtractICalProperty( iCal, "DTSTART:" );
        }

        private static TimeSpan? ExtractICalProperty( string iCal, string property )
        {
            if ( string.IsNullOrWhiteSpace( iCal ) )
            {
                return null;
            }

            var idx = iCal.IndexOf( property, StringComparison.OrdinalIgnoreCase );
            if ( idx < 0 )
            {
                return null;
            }

            idx += property.Length;
            int end = iCal.IndexOfAny( new[] { '\r', '\n' }, idx );
            string dtValue = end >= 0 ? iCal.Substring( idx, end - idx ) : iCal.Substring( idx );
            dtValue = dtValue.Trim();

            if ( dtValue.Length >= 15 && dtValue.Contains( "T" ) )
            {
                var timePart = dtValue.Substring( dtValue.IndexOf( 'T' ) + 1 );
                if ( timePart.Length >= 6 )
                {
                    int hour;
                    int minute;
                    int second = 0;

                    if ( int.TryParse( timePart.Substring( 0, 2 ), out hour ) &&
                        int.TryParse( timePart.Substring( 2, 2 ), out minute ) )
                    {
                        if ( timePart.Length >= 6 )
                        {
                            int.TryParse( timePart.Substring( 4, 2 ), out second );
                        }

                        return new TimeSpan( hour, minute, second );
                    }
                }
            }

            return null;
        }

        private static List<int> ParseCsvInts( string csv )
        {
            var list = new List<int>();

            if ( string.IsNullOrWhiteSpace( csv ) )
            {
                return list;
            }

            var parts = csv.Split( new[] { ',' }, StringSplitOptions.RemoveEmptyEntries );
            foreach ( var p in parts )
            {
                int n;
                if ( int.TryParse( p.Trim(), out n ) && n > 0 )
                {
                    list.Add( n );
                }
            }

            return list;
        }

        /// <summary>
        /// Resuelve el nombre a mostrar del reservante. Se consulta despues del check-in,
        /// fuera de la transaccion del SP, para no alargar el lock del slot.
        /// </summary>
        private static string GetReservationPersonName( RockContext rockContext, int? personAliasId, int? personId )
        {
            // Preferir el alias: sobrevive al merge de personas. PersonId queda como
            // respaldo para filas anteriores a la migracion (Step1) o si el alias
            // viniera nulo por cualquier motivo.
            var person = personAliasId.HasValue
                ? new PersonAliasService( rockContext ).Queryable()
                    .Where( pa => pa.Id == personAliasId.Value )
                    .Select( pa => new { pa.Person.NickName, pa.Person.LastName } )
                    .FirstOrDefault()
                : null;

            if ( person == null && personId.HasValue )
            {
                person = new PersonService( rockContext ).Queryable()
                    .Where( p => p.Id == personId.Value )
                    .Select( p => new { p.NickName, p.LastName } )
                    .FirstOrDefault();
            }

            if ( person == null )
            {
                return string.Empty;
            }

            return BuildPersonName( person.NickName, person.LastName );
        }

        private static string BuildPersonName( string nickName, string lastName )
        {
            return string.Format( "{0} {1}",
                ( nickName ?? string.Empty ).Trim(),
                ( lastName ?? string.Empty ).Trim() ).Trim();
        }

        private static object BuildResult( string status, string name, string message, string scheduleName, int quantity )
        {
            return new
            {
                status = status,
                name = name,
                message = message,
                scheduleName = scheduleName ?? "",
                quantity = quantity
            };
        }

        #endregion

        #region Bags & Helper Classes

        public class InitBag
        {
            public ActiveSlotBag activeSlot { get; set; }
            public string nextScheduleInfo { get; set; }
            public string nextCheckInStartIso { get; set; }

            /// <summary>
            /// Hora del servidor al responder. El cliente la usa para corregir el
            /// desfase de su reloj y que todos los escaneres abran a la vez.
            /// </summary>
            public string serverNowIso { get; set; }
            public int? kioskId { get; set; }
        }

        public class ActiveSlotBag
        {
            public int slotId { get; set; }
            public int scheduleId { get; set; }
            public string scheduleName { get; set; }
            public string occurrenceTime { get; set; }
        }

        public class ProcessScanRequestBag
        {
            public string reservationCode { get; set; }
        }

        private class ActiveSlotResult
        {
            public ActiveSlotBag Slot { get; set; }
            public string NextScheduleInfo { get; set; }
            public string NextCheckInStartIso { get; set; }
        }

        private class SlotScheduleInfo
        {
            public int SlotId { get; set; }
            public int ScheduleId { get; set; }
            public DateTime OccurrenceDate { get; set; }
            public string ScheduleName { get; set; }
            public string iCalendarContent { get; set; }
            public int DoorOpensMinutes { get; set; }
            public int DoorClosesMinutes { get; set; }
        }

        private class ReservationSlotInfo
        {
            public int SlotId { get; set; }
            public DateTime OccurrenceDate { get; set; }
            public bool IsActive { get; set; }
            public string ScheduleName { get; set; }
            public string iCalendarContent { get; set; }
            public int DoorOpensMinutes { get; set; }
            public int DoorClosesMinutes { get; set; }
            public bool InScope { get; set; }
        }

        /// <summary>
        /// Resultado de dbo.sp_SundayServiceCheckIn.
        /// ResultCode: 1 registrado, 0 ya tenia check-in, -1 codigo inexistente,
        /// -2 no pertenece al slot activo, -3 cancelada/no-show, -99 error.
        /// </summary>
        private class CheckInResultRow
        {
            public int ResultCode { get; set; }
            public int? Quantity { get; set; }
            public int? PersonId { get; set; }
            public int? PersonAliasId { get; set; }
        }

        private class InvalidScanThrottleState
        {
            public int Count { get; set; }
            public DateTime WindowStartUtc { get; set; }
            public DateTime? BlockUntilUtc { get; set; }
        }

        #endregion
    }
}
