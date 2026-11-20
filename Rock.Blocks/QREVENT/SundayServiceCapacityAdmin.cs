using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

using Rock;
using Rock.Attribute;
using Rock.Blocks;
using Rock.Data;
using Rock.Model;
using Rock.Security;
using Rock.Web.Cache;

namespace Rock.Blocks.QREVENT
{
    /// <summary>
    /// Administración de disponibilidad (slots) de servicios dominicales.
    /// Permite aplicar una plantilla de horarios × fechas por campus,
    /// y ajustar capacidad o estado de slots individuales.
    /// </summary>
    [DisplayName( "Sunday Service Capacity Admin" )]
    [Category( "Custom" )]
    [Description( "Administra la disponibilidad de los servicios dominicales: genera slots por plantilla y ajusta capacidad o estado individual." )]

    [TextField(
        "Allowed Schedule Ids",
        Description = "Lista de ScheduleIds permitidos, separados por coma (ej: 7,9,11,13,18).",
        IsRequired = true,
        DefaultValue = "",
        Order = 0,
        Key = AttributeKey.AllowedScheduleIds )]

    [IntegerField(
        "Default Campus Id",
        Description = "CampusId preseleccionado al abrir el bloque (opcional).",
        IsRequired = false,
        DefaultIntegerValue = 0,
        Order = 1,
        Key = AttributeKey.DefaultCampusId )]

    [Rock.SystemGuid.EntityTypeGuid( "1cc4e20b-f949-47ae-89bc-4529b30e7a7f" )]
    [Rock.SystemGuid.BlockTypeGuid( "54953569-5e80-40ac-90b1-d43d20a2c34d" )]
    public class SundayServiceCapacityAdmin : RockBlockType
    {
        private static readonly CultureInfo SpanishCulture = new CultureInfo( "es-GT" );

        #region Servicios especiales

        /// <summary>
        /// Categoría de Schedule donde viven los servicios especiales (Nochebuena, un domingo con
        /// horario distinto, etc.) creados desde este bloque. El escáner de la puerta
        /// (<see cref="ReservationScanner"/>) acepta los slots de esta categoría aunque su
        /// ScheduleId no esté en su atributo «Allowed Schedule Ids»: así un servicio especial no
        /// obliga a tocar la configuración de bloques. La categoría se crea sola la primera vez.
        /// </summary>
        public const string SpecialServiceCategoryGuid = "8d391e10-1d7e-40cd-bf57-05f4d63fa89f";

        private const string SpecialServiceCategoryName = "Servicios especiales (Reservas)";

        /// <summary>Duración (DTEND) del Schedule que se crea. Solo informativa: los cortes usan el inicio.</summary>
        private const int SpecialServiceDurationMinutes = 90;

        #endregion

        #region Ventana de la puerta (compartida con ReservationScanner)

        /// <summary>
        /// Minutos antes del inicio en que la puerta empieza a aceptar los QR de un cupo cuando el
        /// cupo no tiene valor propio (columna <c>CheckInOpensMinutesBefore</c> en NULL). Es la
        /// decisión del ministerio del 2026-09-05; cambiarla aquí cambia todos los cupos sin valor.
        /// </summary>
        public const int DefaultDoorOpensMinutesBefore = 15;

        /// <summary>Máximo que acepta la pantalla (la BD admite hasta 240).</summary>
        public const int MaxDoorOpensMinutesBefore = 180;

        /// <summary>
        /// Minutos después del inicio en que la puerta deja de aceptar QR Y la app deja de aceptar
        /// reservas, cuando el cupo no tiene valor propio (columna <c>CheckInClosesMinutesAfter</c> en
        /// NULL). Puerta y reserva cierran juntas: no se emite ningún QR que la puerta vaya a rechazar.
        /// No hay check-out.
        /// </summary>
        public const int DefaultDoorClosesMinutesAfter = 80;

        /// <summary>Rango que acepta la pantalla para el cierre (la BD admite 0 a 720).</summary>
        public const int MinDoorClosesMinutesAfter = 15;
        public const int MaxDoorClosesMinutesAfter = 360;

        private static readonly object DoorColumnLock = new object();
        private static bool _doorColumnExists;
        private static DateTime _doorColumnCheckedUtc = DateTime.MinValue;

        /// <summary>
        /// ¿Ya se corrió <c>Dev Tools/Sql/QREVENT_SundayService_DoorWindow.sql</c> (las DOS columnas)?
        /// Sin ellas, todo funciona con los valores de omisión fijos y la pantalla avisa. Un "sí" se
        /// recuerda para siempre; un "no" se vuelve a preguntar cada minuto (así, correr el script no
        /// exige reiniciar el sitio).
        /// </summary>
        public static bool DoorColumnExists( RockContext rockContext )
        {
            lock ( DoorColumnLock )
            {
                if ( _doorColumnExists || ( DateTime.UtcNow - _doorColumnCheckedUtc ).TotalSeconds < 60 )
                {
                    return _doorColumnExists;
                }
            }

            var exists = rockContext.Database
                .SqlQuery<int>( @"SELECT CASE WHEN COL_LENGTH( 'dbo.SundayServiceSlot', 'CheckInOpensMinutesBefore' ) IS NOT NULL
                                              AND COL_LENGTH( 'dbo.SundayServiceSlot', 'CheckInClosesMinutesAfter' ) IS NOT NULL
                                         THEN 1 ELSE 0 END" )
                .FirstOrDefault() == 1;

            lock ( DoorColumnLock )
            {
                _doorColumnExists = exists;
                _doorColumnCheckedUtc = DateTime.UtcNow;
            }

            return exists;
        }

        /// <summary>
        /// Expresión SQL con los minutos de apertura del cupo cuyo alias es <paramref name="slotAlias"/>
        /// (valor propio o el de omisión). Sin la columna, el valor de omisión fijo.
        /// </summary>
        public static string DoorOpensSqlExpression( RockContext rockContext, string slotAlias )
        {
            return DoorColumnExists( rockContext )
                ? $"ISNULL( {slotAlias}.CheckInOpensMinutesBefore, {DefaultDoorOpensMinutesBefore} )"
                : DefaultDoorOpensMinutesBefore.ToString( CultureInfo.InvariantCulture );
        }

        /// <summary>
        /// Expresión SQL con los minutos de cierre (puerta y reserva) del cupo cuyo alias es
        /// <paramref name="slotAlias"/>. Sin la columna, el valor de omisión fijo.
        /// </summary>
        public static string DoorClosesSqlExpression( RockContext rockContext, string slotAlias )
        {
            return DoorColumnExists( rockContext )
                ? $"ISNULL( {slotAlias}.CheckInClosesMinutesAfter, {DefaultDoorClosesMinutesAfter} )"
                : DefaultDoorClosesMinutesAfter.ToString( CultureInfo.InvariantCulture );
        }

        private const string DoorScriptMissingMessage =
            "Para cambiar a qué hora abre o cierra la puerta falta preparar la base de datos (TI: script QREVENT_SundayService_DoorWindow.sql). "
            + "Mientras tanto la puerta abre 15 min antes y cierra 1 h 20 min después del inicio en todos los servicios.";

        /// <summary>null si la ventana es válida; si no, el mensaje para el usuario. Valores null = no se cambian.</summary>
        private static string ValidateDoorWindow( int? opensMinutes, int? closesMinutes )
        {
            if ( opensMinutes.HasValue && ( opensMinutes.Value < 0 || opensMinutes.Value > MaxDoorOpensMinutesBefore ) )
            {
                return $"La puerta puede abrir desde la hora de inicio hasta {MaxDoorOpensMinutesBefore / 60} horas antes.";
            }

            if ( closesMinutes.HasValue && ( closesMinutes.Value < MinDoorClosesMinutesAfter || closesMinutes.Value > MaxDoorClosesMinutesAfter ) )
            {
                return $"La puerta puede cerrar entre {MinDoorClosesMinutesAfter} minutos y {MaxDoorClosesMinutesAfter / 60} horas después del inicio.";
            }

            return null;
        }

        /// <summary>Expresión SQL (bit): ¿el cupo tiene apertura o cierre propios (no los de omisión)?</summary>
        private static string DoorCustomSqlExpression( RockContext rockContext, string slotAlias )
        {
            return DoorColumnExists( rockContext )
                ? $"CAST( CASE WHEN {slotAlias}.CheckInOpensMinutesBefore IS NULL AND {slotAlias}.CheckInClosesMinutesAfter IS NULL THEN 0 ELSE 1 END AS bit )"
                : "CAST( 0 AS bit )";
        }

        #endregion

        #region Attribute Keys

        private static class AttributeKey
        {
            public const string AllowedScheduleIds = "AllowedScheduleIds";
            public const string DefaultCampusId = "DefaultCampusId";
        }

        #endregion

        #region Initialization

        public override object GetObsidianBlockInitialization()
        {
            if ( !IsAdminAuthorized() )
            {
                return new InitBag
                {
                    notAuthorized = true,
                    campuses = new List<OptionBag>(),
                    schedules = new List<ScheduleBag>()
                };
            }

            var allowedIds = ParseCsvInts( GetAttributeValue( AttributeKey.AllowedScheduleIds ) );

            using ( var rockContext = new RockContext() )
            {
                var campuses = new CampusService( rockContext )
                    .Queryable()
                    .Where( c => c.IsActive ?? true )
                    .OrderBy( c => c.Order ).ThenBy( c => c.Name )
                    .Select( c => new { c.Id, c.Name } )
                    .ToList()
                    .Select( c => new OptionBag { value = c.Id, text = c.Name } )
                    .ToList();

                return new InitBag
                {
                    notAuthorized = false,
                    configError = allowedIds.Count == 0
                        ? "Configura el atributo del bloque 'Allowed Schedule Ids' con los horarios permitidos."
                        : null,
                    campuses = campuses,
                    schedules = GetScheduleBags( rockContext, allowedIds ),
                    defaultCampusId = GetAttributeValue( AttributeKey.DefaultCampusId ).AsInteger(),
                    startDate = RockDateTime.Today.ToString( "yyyy-MM-dd" ),
                    endDate = RockDateTime.Today.AddMonths( 3 ).ToString( "yyyy-MM-dd" ),
                    doorColumnReady = DoorColumnExists( rockContext ),
                    defaultDoorOpensMinutes = DefaultDoorOpensMinutesBefore,
                    maxDoorOpensMinutes = MaxDoorOpensMinutesBefore,
                    doorClosesMinutes = DefaultDoorClosesMinutesAfter,
                    minDoorClosesMinutes = MinDoorClosesMinutesAfter,
                    maxDoorClosesMinutes = MaxDoorClosesMinutesAfter,
                    registrationWindowDays = 7,
                    todayIso = RockDateTime.Today.ToString( "yyyy-MM-dd" )
                };
            }
        }

        #endregion

        #region Block Actions

        /// <summary>
        /// Devuelve los slots del campus en el rango, agrupados por fecha,
        /// más la última capacidad usada por horario (para prellenar la plantilla).
        /// </summary>
        [BlockAction( "GetSlots" )]
        public BlockActionResult GetSlots( GetSlotsRequestBag bag )
        {
            if ( !IsAdminAuthorized() )
            {
                return ActionForbidden( "No autorizado." );
            }

            if ( bag == null || bag.campusId <= 0 )
            {
                return ActionBadRequest( "Parámetros inválidos." );
            }

            if ( !TryParseRange( bag.startDate, bag.endDate, out var start, out var end, out var rangeError ) )
            {
                return ActionBadRequest( rangeError );
            }

            using ( var rockContext = new RockContext() )
            {
                var sql = @"
SELECT
    s.Id AS SlotId,
    s.OccurrenceDate,
    s.ScheduleId,
    sch.[Name] AS ScheduleName,
    s.Capacity,
    s.ReservedCount,
    s.HoldCount,
    s.IsActive,
    -- Personas ya ingresadas (Status 3). Es un subconjunto de ReservedCount,
    -- que cuenta Status IN (1,3); se muestra como 'X de Y ingresaron'.
    ISNULL( (
        SELECT SUM( r.Quantity )
        FROM dbo.SundayServiceReservation r
        WHERE r.SlotId = s.Id AND r.Status = 3
    ), 0 ) AS CheckedInCount,
    CAST( CASE WHEN cat.[Guid] = @SpecialGuid THEN 1 ELSE 0 END AS bit ) AS IsSpecial,
    sch.iCalendarContent AS ICalendarContent,
    " + DoorOpensSqlExpression( rockContext, "s" ) + @" AS DoorOpensMinutes,
    " + DoorClosesSqlExpression( rockContext, "s" ) + @" AS DoorClosesMinutes,
    " + DoorCustomSqlExpression( rockContext, "s" ) + @" AS DoorIsCustom
FROM dbo.SundayServiceSlot s
LEFT JOIN dbo.[Schedule] sch ON sch.Id = s.ScheduleId
LEFT JOIN dbo.[Category] cat ON cat.Id = sch.CategoryId
WHERE s.CampusId = @CampusId
  AND s.OccurrenceDate >= @StartDate
  AND s.OccurrenceDate <= @EndDate
ORDER BY s.OccurrenceDate, sch.[Name]";

                var rows = rockContext.Database.SqlQuery<SlotListRow>(
                    sql,
                    new SqlParameter( "@CampusId", bag.campusId ),
                    new SqlParameter( "@StartDate", start ),
                    new SqlParameter( "@EndDate", end ),
                    new SqlParameter( "@SpecialGuid", new Guid( SpecialServiceCategoryGuid ) )
                ).ToList();

                var days = rows
                    .GroupBy( r => r.OccurrenceDate.Date )
                    .OrderBy( g => g.Key )
                    .Select( g => new DaySlotsBag
                    {
                        occurrenceDate = g.Key.ToString( "yyyy-MM-dd" ),
                        occurrenceDateText = g.Key.ToString( "dddd, dd MMM yyyy", SpanishCulture ),
                        slots = g.Select( r => new SlotBag
                        {
                            slotId = r.SlotId,
                            scheduleId = r.ScheduleId,
                            scheduleName = r.ScheduleName ?? ( "Schedule " + r.ScheduleId ),
                            capacity = r.Capacity,
                            reservedCount = r.ReservedCount,
                            holdCount = r.HoldCount,
                            checkedInCount = r.CheckedInCount,
                            available = Math.Max( 0, r.Capacity - r.ReservedCount - r.HoldCount ),
                            isActive = r.IsActive,
                            isSpecial = r.IsSpecial,
                            timeText = FormatICalTime( r.ICalendarContent ),
                            doorOpensMinutes = r.DoorOpensMinutes,
                            doorClosesMinutes = r.DoorClosesMinutes,
                            doorIsCustom = r.DoorIsCustom
                        } ).ToList()
                    } )
                    .ToList();

                // Última capacidad usada por horario en este campus (prellenado de plantilla)
                var capSql = @"
SELECT x.ScheduleId, x.Capacity
FROM (
    SELECT s.ScheduleId, s.Capacity,
           ROW_NUMBER() OVER ( PARTITION BY s.ScheduleId ORDER BY s.OccurrenceDate DESC, s.Id DESC ) AS rn
    FROM dbo.SundayServiceSlot s
    WHERE s.CampusId = @CampusId
) x
WHERE x.rn = 1";

                var lastCaps = rockContext.Database.SqlQuery<ScheduleCapacityRow>(
                    capSql,
                    new SqlParameter( "@CampusId", bag.campusId )
                ).ToDictionary( r => r.ScheduleId, r => r.Capacity );

                return ActionOk( new GetSlotsResponseBag
                {
                    days = days,
                    templateCapacities = lastCaps
                } );
            }
        }

        /// <summary>
        /// Aplica la plantilla: crea/actualiza slots para cada fecha × horario del rango.
        /// </summary>
        [BlockAction( "Generate" )]
        public BlockActionResult Generate( GenerateRequestBag bag )
        {
            if ( !IsAdminAuthorized() )
            {
                return ActionForbidden( "No autorizado." );
            }

            if ( bag == null || bag.campusId <= 0 )
            {
                return ActionBadRequest( "Parámetros inválidos." );
            }

            if ( !TryParseRange( bag.startDate, bag.endDate, out var start, out var end, out var rangeError ) )
            {
                return ActionBadRequest( rangeError );
            }

            var allowedIds = ParseCsvInts( GetAttributeValue( AttributeKey.AllowedScheduleIds ) );
            var items = ( bag.items ?? new List<GenerateItemBag>() )
                .Where( i => i != null && allowedIds.Contains( i.scheduleId ) && i.capacity >= 0 )
                .GroupBy( i => i.scheduleId )
                .ToDictionary( g => g.Key, g => g.First().capacity );

            if ( items.Count == 0 )
            {
                return ActionBadRequest( "Selecciona al menos un horario permitido." );
            }

            var warnings = new List<string>();
            int inserted = 0, updated = 0, reactivated = 0, deactivated = 0, skippedLowCapacity = 0, skippedSpecialDay = 0;

            using ( var rockContext = new RockContext() )
            {
                // 1) Fechas deseadas por horario según su día (BYDAY del iCalendar)
                var scheduleIds = items.Keys.ToList();
                var schedules = new ScheduleService( rockContext )
                    .Queryable()
                    .Where( s => scheduleIds.Contains( s.Id ) )
                    .Select( s => new { s.Id, s.Name, s.iCalendarContent } )
                    .ToList();

                var desired = new Dictionary<string, int>(); // "yyyy-MM-dd|scheduleId" -> capacity

                foreach ( var kv in items )
                {
                    var sch = schedules.FirstOrDefault( s => s.Id == kv.Key );
                    if ( sch == null )
                    {
                        warnings.Add( $"El horario {kv.Key} no existe; se omitió." );
                        continue;
                    }

                    var days = ExtractByDayTokens( sch.iCalendarContent )
                        .Select( IcalDayToDayOfWeek )
                        .Where( d => d.HasValue )
                        .Select( d => d.Value )
                        .ToList();

                    if ( days.Count == 0 )
                    {
                        warnings.Add( $"'{sch.Name}' no tiene día definido (BYDAY) en su calendario; se omitió." );
                        continue;
                    }

                    foreach ( var dow in days )
                    {
                        foreach ( var date in GetDaysInclusive( start, end, dow ) )
                        {
                            desired[date.ToString( "yyyy-MM-dd" ) + "|" + kv.Key] = kv.Value;
                        }
                    }
                }

                // 2) Slots existentes del rango
                var existing = rockContext.Database.SqlQuery<SlotRow>( @"
SELECT Id AS SlotId, OccurrenceDate, ScheduleId, '' AS ScheduleName, Capacity, ReservedCount, HoldCount, IsActive
FROM dbo.SundayServiceSlot
WHERE CampusId = @CampusId AND OccurrenceDate >= @StartDate AND OccurrenceDate <= @EndDate",
                    new SqlParameter( "@CampusId", bag.campusId ),
                    new SqlParameter( "@StartDate", start ),
                    new SqlParameter( "@EndDate", end )
                ).ToList();

                var existingByKey = existing.ToDictionary(
                    r => r.OccurrenceDate.ToString( "yyyy-MM-dd" ) + "|" + r.ScheduleId,
                    r => r );

                // Servicios especiales del rango. Los días que tienen uno activo se administran a
                // mano desde la lista: la plantilla no crea ni reactiva horarios normales ese día
                // (alguien los desactivó a propósito para dejar solo el especial), y «desactivar los
                // que no estén en la plantilla» nunca apaga un especial.
                var rangeSlots = LoadSlotTimes( rockContext, bag.campusId, start, end );
                var specialSlotIds = new HashSet<int>( rangeSlots.Where( r => r.IsSpecial ).Select( r => r.SlotId ) );
                var datesWithActiveSpecial = new HashSet<DateTime>( rangeSlots
                    .Where( r => r.IsSpecial && r.IsActive )
                    .Select( r => r.OccurrenceDate.Date ) );
                var warnedSpecialDates = new HashSet<DateTime>();

                // 3) Upsert dentro de una sola transacción
                rockContext.WrapTransaction( () =>
                {
                    foreach ( var kv in desired )
                    {
                        var parts = kv.Key.Split( '|' );
                        var date = DateTime.ParseExact( parts[0], "yyyy-MM-dd", CultureInfo.InvariantCulture );
                        var scheduleId = parts[1].AsInteger();
                        var newCapacity = kv.Value;

                        existingByKey.TryGetValue( kv.Key, out var current );
                        var wouldActivate = current == null || !current.IsActive;

                        if ( wouldActivate && datesWithActiveSpecial.Contains( date.Date ) )
                        {
                            skippedSpecialDay++;
                            if ( warnedSpecialDates.Add( date.Date ) )
                            {
                                warnings.Add( $"{parts[0]}: tiene un servicio especial; ese día no se crearon ni reactivaron horarios normales (se administra desde la lista de abajo)." );
                            }

                            continue;
                        }

                        if ( existingByKey.TryGetValue( kv.Key, out var ex ) )
                        {
                            var minNeeded = ex.ReservedCount + ex.HoldCount;

                            if ( bag.overwriteCapacity && newCapacity < minNeeded )
                            {
                                skippedLowCapacity++;
                                warnings.Add( $"{parts[0]}: no se bajó la capacidad a {newCapacity} porque ya hay {minNeeded} lugares tomados (reservas + holds)." );
                                continue;
                            }

                            if ( bag.overwriteCapacity && ex.Capacity != newCapacity )
                            {
                                rockContext.Database.ExecuteSqlCommand(
                                    "UPDATE dbo.SundayServiceSlot SET Capacity = @Capacity, IsActive = 1, ModifiedDateTime = GETDATE() WHERE Id = @Id",
                                    new SqlParameter( "@Capacity", newCapacity ),
                                    new SqlParameter( "@Id", ex.SlotId ) );
                                updated++;
                            }
                            else if ( !ex.IsActive )
                            {
                                rockContext.Database.ExecuteSqlCommand(
                                    "UPDATE dbo.SundayServiceSlot SET IsActive = 1, ModifiedDateTime = GETDATE() WHERE Id = @Id",
                                    new SqlParameter( "@Id", ex.SlotId ) );
                                reactivated++;
                            }
                        }
                        else
                        {
                            rockContext.Database.ExecuteSqlCommand( @"
INSERT INTO dbo.SundayServiceSlot ( CampusId, OccurrenceDate, ScheduleId, Capacity, ReservedCount, HoldCount, IsActive, CreatedDateTime, ModifiedDateTime )
VALUES ( @CampusId, @OccurrenceDate, @ScheduleId, @Capacity, 0, 0, 1, GETDATE(), GETDATE() )",
                                new SqlParameter( "@CampusId", bag.campusId ),
                                new SqlParameter( "@OccurrenceDate", date ),
                                new SqlParameter( "@ScheduleId", scheduleId ),
                                new SqlParameter( "@Capacity", newCapacity ) );
                            inserted++;
                        }
                    }

                    // 4) Desactivar slots del rango que no están en la plantilla
                    if ( bag.deactivateOthers )
                    {
                        foreach ( var ex in existing )
                        {
                            var key = ex.OccurrenceDate.ToString( "yyyy-MM-dd" ) + "|" + ex.ScheduleId;
                            if ( desired.ContainsKey( key ) || !ex.IsActive || specialSlotIds.Contains( ex.SlotId ) )
                            {
                                continue;
                            }

                            if ( ex.ReservedCount == 0 && ex.HoldCount == 0 )
                            {
                                rockContext.Database.ExecuteSqlCommand(
                                    "UPDATE dbo.SundayServiceSlot SET IsActive = 0, ModifiedDateTime = GETDATE() WHERE Id = @Id",
                                    new SqlParameter( "@Id", ex.SlotId ) );
                                deactivated++;
                            }
                            else
                            {
                                warnings.Add( $"{ex.OccurrenceDate:yyyy-MM-dd}: no se desactivó un horario fuera de plantilla porque tiene {ex.ReservedCount} reservados y {ex.HoldCount} holds." );
                            }
                        }
                    }
                } );
            }

            return ActionOk( new GenerateResponseBag
            {
                inserted = inserted,
                updated = updated,
                reactivated = reactivated,
                deactivated = deactivated,
                skippedLowCapacity = skippedLowCapacity,
                skippedSpecialDay = skippedSpecialDay,
                warnings = warnings
            } );
        }

        /// <summary>
        /// Ajusta un slot individual: capacidad, estado activo y/o ventana de la puerta
        /// (<c>doorOpensMinutes</c> / <c>doorClosesMinutes</c>, o <c>resetDoorToDefault</c> para volver
        /// a los valores de omisión). Un valor igual al de omisión se guarda como NULL.
        /// </summary>
        [BlockAction( "UpdateSlot" )]
        public BlockActionResult UpdateSlot( UpdateSlotRequestBag bag )
        {
            if ( !IsAdminAuthorized() )
            {
                return ActionForbidden( "No autorizado." );
            }

            var changesDoor = bag != null && ( bag.doorOpensMinutes.HasValue || bag.doorClosesMinutes.HasValue || bag.resetDoorToDefault );

            if ( bag == null || bag.slotId <= 0 || ( !bag.capacity.HasValue && !bag.isActive.HasValue && !changesDoor ) )
            {
                return ActionBadRequest( "Parámetros inválidos." );
            }

            var doorError = ValidateDoorWindow( bag.doorOpensMinutes, bag.doorClosesMinutes );
            if ( doorError != null )
            {
                return ActionBadRequest( doorError );
            }

            using ( var rockContext = new RockContext() )
            {
                var row = rockContext.Database.SqlQuery<SlotRow>( @"
SELECT Id AS SlotId, OccurrenceDate, ScheduleId, '' AS ScheduleName, Capacity, ReservedCount, HoldCount, IsActive
FROM dbo.SundayServiceSlot WHERE Id = @Id",
                    new SqlParameter( "@Id", bag.slotId ) ).FirstOrDefault();

                if ( row == null )
                {
                    return ActionOk( new UpdateSlotResponseBag { resultCode = -1, message = "El slot ya no existe." } );
                }

                var taken = row.ReservedCount + row.HoldCount;

                if ( bag.capacity.HasValue && bag.capacity.Value < taken )
                {
                    return ActionOk( new UpdateSlotResponseBag
                    {
                        resultCode = 0,
                        message = $"No puedes bajar la capacidad a {bag.capacity.Value}: ya hay {taken} lugares tomados (reservas + holds)."
                    } );
                }

                if ( bag.isActive.HasValue && !bag.isActive.Value && taken > 0 )
                {
                    return ActionOk( new UpdateSlotResponseBag
                    {
                        resultCode = 0,
                        message = $"No puedes desactivar este horario: tiene {row.ReservedCount} reservados y {row.HoldCount} holds."
                    } );
                }

                // Ya no se bloquea reactivar por «choque» de ventanas: desde 2026-11-20 el escáner
                // valida cada QR contra la ventana de SU propio cupo, así que dos ventanas que se
                // cruzan ya no rechazan reservas válidas. La pantalla solo lo muestra.

                if ( changesDoor && !DoorColumnExists( rockContext ) )
                {
                    return ActionOk( new UpdateSlotResponseBag
                    {
                        resultCode = 0,
                        message = DoorScriptMissingMessage
                    } );
                }

                // Columnas de la ventana: reset = las dos a NULL; si no, solo las que vienen (un valor
                // igual al de omisión se guarda NULL para que siga al valor de omisión si algún día cambia).
                var doorSet = "";
                object doorOpensValue = DBNull.Value;
                object doorClosesValue = DBNull.Value;

                if ( bag.resetDoorToDefault )
                {
                    doorSet = ", CheckInOpensMinutesBefore = NULL, CheckInClosesMinutesAfter = NULL";
                }
                else
                {
                    if ( bag.doorOpensMinutes.HasValue )
                    {
                        doorSet += ", CheckInOpensMinutesBefore = @DoorOpens";
                        doorOpensValue = bag.doorOpensMinutes.Value == DefaultDoorOpensMinutesBefore ? ( object ) DBNull.Value : bag.doorOpensMinutes.Value;
                    }

                    if ( bag.doorClosesMinutes.HasValue )
                    {
                        doorSet += ", CheckInClosesMinutesAfter = @DoorCloses";
                        doorClosesValue = bag.doorClosesMinutes.Value == DefaultDoorClosesMinutesAfter ? ( object ) DBNull.Value : bag.doorClosesMinutes.Value;
                    }
                }

                rockContext.Database.ExecuteSqlCommand( @"
UPDATE dbo.SundayServiceSlot
SET Capacity = ISNULL( @Capacity, Capacity ),
    IsActive = ISNULL( @IsActive, IsActive ),
    ModifiedDateTime = GETDATE()" + doorSet + @"
WHERE Id = @Id",
                    new SqlParameter( "@Capacity", ( object ) bag.capacity ?? DBNull.Value ),
                    new SqlParameter( "@IsActive", ( object ) bag.isActive ?? DBNull.Value ),
                    new SqlParameter( "@DoorOpens", doorOpensValue ),
                    new SqlParameter( "@DoorCloses", doorClosesValue ),
                    new SqlParameter( "@Id", bag.slotId ) );

                return ActionOk( new UpdateSlotResponseBag { resultCode = 1, message = "Guardado." } );
            }
        }

        /// <summary>
        /// Servicios especiales del campus desde hoy (activos e inactivos), para verlos todos en la
        /// tarjeta «Servicio especial» sin mover el rango de fechas de la lista.
        /// </summary>
        [BlockAction( "GetUpcomingSpecialServices" )]
        public BlockActionResult GetUpcomingSpecialServices( GetSlotsRequestBag bag )
        {
            if ( !IsAdminAuthorized() )
            {
                return ActionForbidden( "No autorizado." );
            }

            if ( bag == null || bag.campusId <= 0 )
            {
                return ActionBadRequest( "Parámetros inválidos." );
            }

            using ( var rockContext = new RockContext() )
            {
                // Mismas columnas que GetSlots: SlotListRow exige todas (ver su comentario).
                var rows = rockContext.Database.SqlQuery<SlotListRow>( @"
SELECT TOP 100
    s.Id AS SlotId,
    s.OccurrenceDate,
    s.ScheduleId,
    sch.[Name] AS ScheduleName,
    s.Capacity,
    s.ReservedCount,
    s.HoldCount,
    s.IsActive,
    ISNULL( (
        SELECT SUM( r.Quantity )
        FROM dbo.SundayServiceReservation r
        WHERE r.SlotId = s.Id AND r.Status = 3
    ), 0 ) AS CheckedInCount,
    CAST( 1 AS bit ) AS IsSpecial,
    sch.iCalendarContent AS ICalendarContent,
    " + DoorOpensSqlExpression( rockContext, "s" ) + @" AS DoorOpensMinutes,
    " + DoorClosesSqlExpression( rockContext, "s" ) + @" AS DoorClosesMinutes,
    " + DoorCustomSqlExpression( rockContext, "s" ) + @" AS DoorIsCustom
FROM dbo.SundayServiceSlot s
INNER JOIN dbo.[Schedule] sch ON sch.Id = s.ScheduleId
INNER JOIN dbo.[Category] cat ON cat.Id = sch.CategoryId
WHERE s.CampusId = @CampusId
  AND s.OccurrenceDate >= @Today
  AND cat.[Guid] = @SpecialGuid
ORDER BY s.OccurrenceDate, s.Id",
                    new SqlParameter( "@CampusId", bag.campusId ),
                    new SqlParameter( "@Today", RockDateTime.Today ),
                    new SqlParameter( "@SpecialGuid", new Guid( SpecialServiceCategoryGuid ) )
                ).ToList();

                var items = rows
                    .Select( r => new UpcomingSpecialBag
                    {
                        slotId = r.SlotId,
                        scheduleId = r.ScheduleId,
                        scheduleName = r.ScheduleName ?? ( "Schedule " + r.ScheduleId ),
                        capacity = r.Capacity,
                        reservedCount = r.ReservedCount,
                        holdCount = r.HoldCount,
                        checkedInCount = r.CheckedInCount,
                        available = Math.Max( 0, r.Capacity - r.ReservedCount - r.HoldCount ),
                        isActive = r.IsActive,
                        isSpecial = true,
                        timeText = FormatICalTime( r.ICalendarContent ),
                        doorOpensMinutes = r.DoorOpensMinutes,
                        doorClosesMinutes = r.DoorClosesMinutes,
                        doorIsCustom = r.DoorIsCustom,
                        occurrenceDate = r.OccurrenceDate.ToString( "yyyy-MM-dd" ),
                        occurrenceDateText = r.OccurrenceDate.ToString( "ddd d MMM yyyy", SpanishCulture ).Replace( ".", "" )
                    } )
                    .OrderBy( x => x.occurrenceDate )
                    .ThenBy( x => x.timeText )
                    .ToList();

                return ActionOk( items );
            }
        }

        /// <summary>
        /// Crea un servicio especial (Nochebuena, un domingo con horario distinto, etc.) para
        /// una fecha y hora concretas, sin tocar la configuración de los bloques: crea el
        /// Schedule de una sola fecha en la categoría <see cref="SpecialServiceCategoryGuid"/>
        /// y su slot con la capacidad indicada. La app de reservas lo muestra en su ventana
        /// normal (7 días antes) y el escáner lo acepta por la categoría.
        /// </summary>
        [BlockAction( "CreateSpecialService" )]
        public BlockActionResult CreateSpecialService( CreateSpecialServiceRequestBag bag )
        {
            if ( !IsAdminAuthorized() )
            {
                return ActionForbidden( "No autorizado." );
            }

            if ( bag == null || bag.campusId <= 0 || CampusCache.Get( bag.campusId ) == null )
            {
                return ActionBadRequest( "Selecciona una sede válida." );
            }

            if ( !DateTime.TryParseExact( bag.date ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var date ) )
            {
                return ActionBadRequest( "Indica la fecha del servicio." );
            }

            if ( !TimeSpan.TryParseExact( bag.time ?? "", @"hh\:mm", CultureInfo.InvariantCulture, out var time ) || time.TotalHours >= 24 )
            {
                return ActionBadRequest( "Indica la hora de inicio del servicio." );
            }

            if ( bag.capacity <= 0 || bag.capacity > 100000 )
            {
                return ActionBadRequest( "La capacidad debe ser mayor que cero." );
            }

            var doorOpens = bag.doorOpensMinutes ?? DefaultDoorOpensMinutesBefore;
            var doorCloses = bag.doorClosesMinutes ?? DefaultDoorClosesMinutesAfter;
            var doorError = ValidateDoorWindow( doorOpens, doorCloses );
            if ( doorError != null )
            {
                return ActionBadRequest( doorError );
            }

            var label = ( bag.name ?? "" ).Trim();
            if ( Regex.IsMatch( label, @"\d{1,2}\s*:\s*\d{2}" ) )
            {
                // La app de reservas ordena los horarios por la hora que aparece en el nombre;
                // una hora escrita a mano que no coincida con la real los desordenaría.
                return ActionBadRequest( "Quita la hora del nombre: se agrega sola con la hora indicada." );
            }

            if ( label.Length == 0 )
            {
                label = "Servicio especial";
            }

            var name = label + " " + DateTime.Today.Add( time ).ToString( "H:mm", CultureInfo.InvariantCulture ) + " h";
            if ( name.Length > 50 )
            {
                return ActionBadRequest( "El nombre es demasiado largo: máximo 40 caracteres." );
            }

            var now = RockDateTime.Now;
            var startDateTime = date.Date.Add( time );

            if ( startDateTime.AddMinutes( doorCloses ) <= now )
            {
                return ActionBadRequest( "Esa fecha y hora ya pasaron (la puerta ya habría cerrado)." );
            }

            if ( date.Date > now.Date.AddDays( 400 ) )
            {
                return ActionBadRequest( "La fecha está demasiado lejos (máximo 400 días)." );
            }

            using ( var rockContext = new RockContext() )
            {
                // Sin las columnas solo se admiten los valores de omisión (no hay dónde guardar otros).
                var doorColumn = DoorColumnExists( rockContext );
                var customDoor = doorOpens != DefaultDoorOpensMinutesBefore || doorCloses != DefaultDoorClosesMinutesAfter;
                if ( !doorColumn && customDoor )
                {
                    return ActionOk( new CreateSpecialServiceResponseBag
                    {
                        resultCode = 0,
                        message = DoorScriptMissingMessage
                    } );
                }

                // Valor propio solo si difiere del de omisión (si no, NULL): así un cambio futuro del
                // valor de omisión también alcanza a los especiales creados «con lo normal».
                var storeDoor = doorColumn && customDoor;
                object doorOpensValue = doorOpens == DefaultDoorOpensMinutesBefore ? ( object ) DBNull.Value : doorOpens;
                object doorClosesValue = doorCloses == DefaultDoorClosesMinutesAfter ? ( object ) DBNull.Value : doorCloses;

                rockContext.WrapTransaction( () =>
                {
                    var category = GetOrCreateSpecialCategory( rockContext );

                    var schedule = new Schedule
                    {
                        Name = name,
                        Description = "Servicio especial de reservas creado desde Configuración Domingos el "
                            + now.ToString( "dd/MM/yyyy HH:mm", CultureInfo.InvariantCulture )
                            + ( RequestContext?.CurrentPerson != null ? " por " + RequestContext.CurrentPerson.FullName : "" ) + ".",
                        CategoryId = category.Id,
                        IsActive = true,
                        iCalendarContent = BuildSingleDateICal( startDateTime, SpecialServiceDurationMinutes, now )
                    };

                    new ScheduleService( rockContext ).Add( schedule );
                    rockContext.SaveChanges();

                    rockContext.Database.ExecuteSqlCommand( @"
INSERT INTO dbo.SundayServiceSlot ( CampusId, OccurrenceDate, ScheduleId, Capacity, ReservedCount, HoldCount, IsActive, CreatedDateTime, ModifiedDateTime" + ( storeDoor ? ", CheckInOpensMinutesBefore, CheckInClosesMinutesAfter" : "" ) + @" )
VALUES ( @CampusId, @OccurrenceDate, @ScheduleId, @Capacity, 0, 0, 1, GETDATE(), GETDATE()" + ( storeDoor ? ", @DoorOpens, @DoorCloses" : "" ) + @" )",
                        new SqlParameter( "@CampusId", bag.campusId ),
                        new SqlParameter( "@OccurrenceDate", date.Date ),
                        new SqlParameter( "@ScheduleId", schedule.Id ),
                        new SqlParameter( "@Capacity", bag.capacity ),
                        new SqlParameter( "@DoorOpens", doorOpensValue ),
                        new SqlParameter( "@DoorCloses", doorClosesValue ) );
                } );

                return ActionOk( new CreateSpecialServiceResponseBag
                {
                    resultCode = 1,
                    message = $"Listo: «{name}» el {date.ToString( "dddd d 'de' MMMM", SpanishCulture )}.",
                    scheduleName = name,
                    occurrenceDate = date.ToString( "yyyy-MM-dd" )
                } );
            }
        }

        /// <summary>
        /// Métricas semanales para la pestaña de dashboard: por semana y, dentro de
        /// cada semana, por horario. Reservados / Ingresaron / No vinieron / Pendientes,
        /// siempre en PERSONAS (SUM(Quantity)), para que sea comparable con
        /// ReservedCount.
        ///
        /// Reglas:
        ///  - Reservados  = Status IN (1,3)  (misma fórmula que ReservedCount).
        ///  - Ingresaron  = Status = 3.
        ///  - Un slot es "pasado" si su fecha es anterior a hoy. Solo entonces la
        ///    diferencia Reservados − Ingresaron se reporta como "No vinieron"; para
        ///    hoy y el futuro esa diferencia es "Pendientes" (todavía pueden llegar).
        ///  - Semana = lunes a domingo; se etiqueta por el domingo, que es el día de
        ///    servicio.
        /// No toca esquema ni SPs: se calcula sobre las tablas existentes.
        /// </summary>
        [BlockAction( "GetWeeklyMetrics" )]
        public BlockActionResult GetWeeklyMetrics( GetSlotsRequestBag bag )
        {
            if ( !IsAdminAuthorized() )
            {
                return ActionForbidden( "No autorizado." );
            }

            if ( bag == null || bag.campusId <= 0 )
            {
                return ActionBadRequest( "Parámetros inválidos." );
            }

            if ( !TryParseRange( bag.startDate, bag.endDate, out var start, out var end, out var rangeError ) )
            {
                return ActionBadRequest( rangeError );
            }

            var allowedIds = ParseCsvInts( GetAttributeValue( AttributeKey.AllowedScheduleIds ) );
            var today = RockDateTime.Today;

            using ( var rockContext = new RockContext() )
            {
                var sql = @"
SELECT
    s.Id AS SlotId,
    s.OccurrenceDate,
    s.ScheduleId,
    sch.[Name] AS ScheduleName,
    s.Capacity,
    ISNULL( (
        SELECT SUM( r.Quantity )
        FROM dbo.SundayServiceReservation r
        WHERE r.SlotId = s.Id AND r.Status IN ( 1, 3 )
    ), 0 ) AS ReservedPeople,
    ISNULL( (
        SELECT SUM( r.Quantity )
        FROM dbo.SundayServiceReservation r
        WHERE r.SlotId = s.Id AND r.Status = 3
    ), 0 ) AS CheckedInPeople
FROM dbo.SundayServiceSlot s
LEFT JOIN dbo.[Schedule] sch ON sch.Id = s.ScheduleId
WHERE s.CampusId = @CampusId
  AND s.OccurrenceDate >= @StartDate
  AND s.OccurrenceDate <= @EndDate
ORDER BY s.OccurrenceDate";

                var rows = rockContext.Database.SqlQuery<MetricsSlotRow>(
                    sql,
                    new SqlParameter( "@CampusId", bag.campusId ),
                    new SqlParameter( "@StartDate", start ),
                    new SqlParameter( "@EndDate", end )
                ).ToList();

                var weeks = rows
                    .GroupBy( r => WeekStartMonday( r.OccurrenceDate ) )
                    .OrderBy( g => g.Key )
                    .Select( g =>
                    {
                        var sunday = g.Key.AddDays( 6 );

                        var schedules = g
                            .GroupBy( r => r.ScheduleId )
                            .Select( sg => BuildScheduleMetrics( sg.Key, sg.First().ScheduleName, sg.ToList(), today ) )
                            // Mismo orden que el atributo del bloque (7,9,11,13,18); lo no listado al final.
                            .OrderBy( m => { var i = allowedIds.IndexOf( m.scheduleId ); return i < 0 ? int.MaxValue : i; } )
                            .ThenBy( m => m.scheduleName )
                            .ToList();

                        return new WeekMetricsBag
                        {
                            weekStart = g.Key.ToString( "yyyy-MM-dd" ),
                            sundayDate = sunday.ToString( "yyyy-MM-dd" ),
                            label = "Dom " + sunday.ToString( "d MMM", SpanishCulture ).Replace( ".", "" ),
                            isPast = sunday < today,
                            capacity = schedules.Sum( m => m.capacity ),
                            reserved = schedules.Sum( m => m.reserved ),
                            checkedIn = schedules.Sum( m => m.checkedIn ),
                            noShow = schedules.Sum( m => m.noShow ),
                            pending = schedules.Sum( m => m.pending ),
                            schedules = schedules
                        };
                    } )
                    .ToList();

                return ActionOk( new WeeklyMetricsResponseBag { weeks = weeks } );
            }
        }

        #endregion

        #region Helpers

        /// <summary>Lunes de la semana a la que pertenece la fecha (lunes → domingo).</summary>
        private static DateTime WeekStartMonday( DateTime date )
        {
            var offset = ( ( int ) date.DayOfWeek + 6 ) % 7;
            return date.Date.AddDays( -offset );
        }

        private static ScheduleMetricsBag BuildScheduleMetrics( int scheduleId, string scheduleName, List<MetricsSlotRow> slots, DateTime today )
        {
            var reserved = 0;
            var checkedIn = 0;
            var noShow = 0;
            var pending = 0;
            var capacity = 0;
            var allPast = true;

            foreach ( var s in slots )
            {
                var isPast = s.OccurrenceDate.Date < today;
                var gap = Math.Max( 0, s.ReservedPeople - s.CheckedInPeople );

                reserved += s.ReservedPeople;
                checkedIn += s.CheckedInPeople;
                capacity += s.Capacity;

                if ( isPast )
                {
                    noShow += gap;
                }
                else
                {
                    pending += gap;
                    allPast = false;
                }
            }

            return new ScheduleMetricsBag
            {
                scheduleId = scheduleId,
                scheduleName = scheduleName ?? ( "Schedule " + scheduleId ),
                capacity = capacity,
                reserved = reserved,
                checkedIn = checkedIn,
                noShow = noShow,
                pending = pending,
                isPast = allPast
            };
        }

        private bool IsAdminAuthorized()
        {
            var currentPerson = RequestContext?.CurrentPerson;
            return currentPerson != null && BlockCache.IsAuthorized( Authorization.EDIT, currentPerson );
        }

        /// <summary>
        /// Slots (activos e inactivos) del campus en el rango, con el iCal de su Schedule y si son
        /// servicios especiales. Lo usa la plantilla para respetar los días con servicio especial.
        /// </summary>
        private static List<SlotTimeRow> LoadSlotTimes( RockContext rockContext, int campusId, DateTime start, DateTime end )
        {
            return rockContext.Database.SqlQuery<SlotTimeRow>( @"
SELECT
    s.Id AS SlotId,
    s.OccurrenceDate,
    ISNULL( sch.[Name], 'Schedule ' + CAST( s.ScheduleId AS varchar(12) ) ) AS ScheduleName,
    sch.iCalendarContent AS ICalendarContent,
    s.IsActive,
    CAST( CASE WHEN cat.[Guid] = @SpecialGuid THEN 1 ELSE 0 END AS bit ) AS IsSpecial
FROM dbo.SundayServiceSlot s
LEFT JOIN dbo.[Schedule] sch ON sch.Id = s.ScheduleId
LEFT JOIN dbo.[Category] cat ON cat.Id = sch.CategoryId
WHERE s.CampusId = @CampusId
  AND s.OccurrenceDate >= @StartDate
  AND s.OccurrenceDate <= @EndDate",
                new SqlParameter( "@CampusId", campusId ),
                new SqlParameter( "@StartDate", start.Date ),
                new SqlParameter( "@EndDate", end.Date ),
                new SqlParameter( "@SpecialGuid", new Guid( SpecialServiceCategoryGuid ) )
            ).ToList();
        }

        private static string FormatICalTime( string iCal )
        {
            var time = ExtractICalTime( iCal, "DTSTART:" );
            return time.HasValue ? DateTime.Today.Add( time.Value ).ToString( "HH:mm", CultureInfo.InvariantCulture ) : "";
        }

        private static Category GetOrCreateSpecialCategory( RockContext rockContext )
        {
            var guid = new Guid( SpecialServiceCategoryGuid );
            var categoryService = new CategoryService( rockContext );
            var category = categoryService.Get( guid );

            if ( category != null )
            {
                return category;
            }

            category = new Category
            {
                Guid = guid,
                Name = SpecialServiceCategoryName,
                Description = "Servicios especiales (Nochebuena, cambios de horario) creados desde Configuración Domingos. El escáner de reservas los acepta sin configurar el bloque. No mover sus horarios a otra categoría.",
                EntityTypeId = EntityTypeCache.Get( typeof( Schedule ) ).Id,
                IconCssClass = "fa fa-star",
                IsSystem = false,
                Order = 0
            };

            categoryService.Add( category );
            rockContext.SaveChanges();

            return category;
        }

        /// <summary>
        /// iCal de una sola fecha (sin RRULE), con DTSTART sin zona horaria: es lo que esperan los
        /// parsers de este módulo (registro, escáner y este bloque leen la hora de DTSTART).
        /// </summary>
        private static string BuildSingleDateICal( DateTime start, int durationMinutes, DateTime now )
        {
            const string fmt = "yyyyMMdd'T'HHmmss";

            return string.Join( "\r\n", new[]
            {
                "BEGIN:VCALENDAR",
                "PRODID:-//github.com/SparkDevNetwork/Rock//NONSGML Rock//EN",
                "VERSION:2.0",
                "BEGIN:VEVENT",
                "DTEND:" + start.AddMinutes( durationMinutes ).ToString( fmt, CultureInfo.InvariantCulture ),
                "DTSTAMP:" + now.ToString( fmt, CultureInfo.InvariantCulture ),
                "DTSTART:" + start.ToString( fmt, CultureInfo.InvariantCulture ),
                "SEQUENCE:0",
                "UID:" + Guid.NewGuid().ToString(),
                "END:VEVENT",
                "END:VCALENDAR"
            } ) + "\r\n";
        }

        private static bool TryParseRange( string startDate, string endDate, out DateTime start, out DateTime end, out string error )
        {
            start = default;
            end = default;
            error = null;

            if ( !DateTime.TryParseExact( startDate, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out start )
                 || !DateTime.TryParseExact( endDate, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out end ) )
            {
                error = "Fechas inválidas.";
                return false;
            }

            if ( start > end )
            {
                error = "La fecha de inicio debe ser anterior a la fecha fin.";
                return false;
            }

            if ( ( end - start ).TotalDays > 400 )
            {
                error = "El rango máximo es de 400 días.";
                return false;
            }

            return true;
        }

        private static List<ScheduleBag> GetScheduleBags( RockContext rockContext, List<int> allowedIds )
        {
            if ( allowedIds.Count == 0 )
            {
                return new List<ScheduleBag>();
            }

            var schedules = new ScheduleService( rockContext )
                .Queryable()
                .Where( s => allowedIds.Contains( s.Id ) )
                .Select( s => new { s.Id, s.Name, s.iCalendarContent } )
                .ToList();

            return schedules
                .Select( s =>
                {
                    var dow = ExtractByDayTokens( s.iCalendarContent )
                        .Select( IcalDayToDayOfWeek )
                        .FirstOrDefault( d => d.HasValue );

                    var time = ExtractICalTime( s.iCalendarContent, "DTSTART:" );

                    return new ScheduleBag
                    {
                        id = s.Id,
                        name = s.Name,
                        dayOfWeek = dow.HasValue ? ( int ) dow.Value : -1,
                        dayText = dow.HasValue ? SpanishCulture.DateTimeFormat.GetDayName( dow.Value ) : "sin día",
                        timeText = time.HasValue ? DateTime.Today.Add( time.Value ).ToString( "HH:mm" ) : ""
                    };
                } )
                .OrderBy( s => s.dayOfWeek )
                .ThenBy( s => s.timeText )
                .ToList();
        }

        private static List<int> ParseCsvInts( string csv )
        {
            var list = new List<int>();
            if ( string.IsNullOrWhiteSpace( csv ) )
            {
                return list;
            }

            foreach ( var p in csv.Split( new[] { ',' }, StringSplitOptions.RemoveEmptyEntries ) )
            {
                if ( int.TryParse( p.Trim(), out var n ) && n > 0 )
                {
                    list.Add( n );
                }
            }

            return list;
        }

        private static List<string> ExtractByDayTokens( string iCal )
        {
            var list = new List<string>();
            if ( string.IsNullOrWhiteSpace( iCal ) )
            {
                return list;
            }

            var idx = iCal.IndexOf( "BYDAY=", StringComparison.OrdinalIgnoreCase );
            if ( idx < 0 )
            {
                return list;
            }

            idx += 6;
            var end = iCal.IndexOfAny( new[] { '\r', '\n' }, idx );
            var raw = end >= 0 ? iCal.Substring( idx, end - idx ) : iCal.Substring( idx );

            var semi = raw.IndexOf( ';' );
            if ( semi >= 0 )
            {
                raw = raw.Substring( 0, semi );
            }

            foreach ( var p in raw.Split( new[] { ',' }, StringSplitOptions.RemoveEmptyEntries ) )
            {
                var t = p.Trim().ToUpperInvariant();
                if ( t.Length > 2 )
                {
                    t = t.Substring( t.Length - 2, 2 ); // 1SU, -1SA, etc.
                }

                if ( ( t == "SU" || t == "MO" || t == "TU" || t == "WE" || t == "TH" || t == "FR" || t == "SA" ) && !list.Contains( t ) )
                {
                    list.Add( t );
                }
            }

            return list;
        }

        private static DayOfWeek? IcalDayToDayOfWeek( string token )
        {
            switch ( ( token ?? "" ).Trim().ToUpperInvariant() )
            {
                case "SU": return DayOfWeek.Sunday;
                case "MO": return DayOfWeek.Monday;
                case "TU": return DayOfWeek.Tuesday;
                case "WE": return DayOfWeek.Wednesday;
                case "TH": return DayOfWeek.Thursday;
                case "FR": return DayOfWeek.Friday;
                case "SA": return DayOfWeek.Saturday;
                default: return null;
            }
        }

        private static TimeSpan? ExtractICalTime( string iCal, string property )
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
            var end = iCal.IndexOfAny( new[] { '\r', '\n' }, idx );
            var dtValue = ( end >= 0 ? iCal.Substring( idx, end - idx ) : iCal.Substring( idx ) ).Trim();

            var tIdx = dtValue.IndexOf( 'T' );
            if ( tIdx < 0 || dtValue.Length < tIdx + 5 )
            {
                return null;
            }

            var timePart = dtValue.Substring( tIdx + 1 );
            if ( int.TryParse( timePart.Substring( 0, 2 ), out var hour )
                 && int.TryParse( timePart.Substring( 2, 2 ), out var minute ) )
            {
                return new TimeSpan( hour, minute, 0 );
            }

            return null;
        }

        private static List<DateTime> GetDaysInclusive( DateTime start, DateTime end, DayOfWeek target )
        {
            var list = new List<DateTime>();
            var daysToTarget = ( ( int ) target - ( int ) start.DayOfWeek + 7 ) % 7;
            var d = start.AddDays( daysToTarget ).Date;

            while ( d <= end.Date )
            {
                list.Add( d );
                d = d.AddDays( 7 );
            }

            return list;
        }

        #endregion

        #region DTOs

        public class InitBag
        {
            public bool notAuthorized { get; set; }
            public string configError { get; set; }
            public List<OptionBag> campuses { get; set; }
            public List<ScheduleBag> schedules { get; set; }
            public int defaultCampusId { get; set; }
            public string startDate { get; set; }
            public string endDate { get; set; }

            /// <summary>false = falta el script DoorWindow: la apertura queda fija en el valor de omisión.</summary>
            public bool doorColumnReady { get; set; }

            public int defaultDoorOpensMinutes { get; set; }
            public int maxDoorOpensMinutes { get; set; }
            public int doorClosesMinutes { get; set; }
            public int minDoorClosesMinutes { get; set; }
            public int maxDoorClosesMinutes { get; set; }

            /// <summary>Días que muestra la app de reservas (DefaultWeekDaysWindow de SundayServiceRegistration).</summary>
            public int registrationWindowDays { get; set; }

            /// <summary>Hoy según el servidor (yyyy-MM-dd), para no depender del reloj del equipo.</summary>
            public string todayIso { get; set; }
        }

        public class OptionBag
        {
            public int value { get; set; }
            public string text { get; set; }
        }

        public class ScheduleBag
        {
            public int id { get; set; }
            public string name { get; set; }
            public int dayOfWeek { get; set; }
            public string dayText { get; set; }
            public string timeText { get; set; }
        }

        public class GetSlotsRequestBag
        {
            public int campusId { get; set; }
            public string startDate { get; set; }
            public string endDate { get; set; }
        }

        public class GetSlotsResponseBag
        {
            public List<DaySlotsBag> days { get; set; }
            public Dictionary<int, int> templateCapacities { get; set; }
        }

        public class DaySlotsBag
        {
            public string occurrenceDate { get; set; }
            public string occurrenceDateText { get; set; }
            public List<SlotBag> slots { get; set; }
        }

        public class SlotBag
        {
            public int slotId { get; set; }
            public int scheduleId { get; set; }
            public string scheduleName { get; set; }
            public int capacity { get; set; }
            public int reservedCount { get; set; }
            public int holdCount { get; set; }
            public int checkedInCount { get; set; }
            public int available { get; set; }
            public bool isActive { get; set; }
            public bool isSpecial { get; set; }

            /// <summary>Hora de inicio (DTSTART) en HH:mm; vacío si el Schedule no la trae.</summary>
            public string timeText { get; set; }

            /// <summary>Minutos antes del inicio en que abre la puerta (propio o de omisión).</summary>
            public int doorOpensMinutes { get; set; }

            /// <summary>Minutos después del inicio en que cierran puerta y reserva (propio o de omisión).</summary>
            public int doorClosesMinutes { get; set; }

            /// <summary>true si el cupo tiene apertura propia; false = usa el valor de omisión.</summary>
            public bool doorIsCustom { get; set; }
        }

        public class UpcomingSpecialBag : SlotBag
        {
            public string occurrenceDate { get; set; }
            public string occurrenceDateText { get; set; }
        }

        public class CreateSpecialServiceRequestBag
        {
            public int campusId { get; set; }

            /// <summary>yyyy-MM-dd</summary>
            public string date { get; set; }

            /// <summary>HH:mm (24 h)</summary>
            public string time { get; set; }

            /// <summary>Opcional; sin hora (se agrega sola).</summary>
            public string name { get; set; }

            public int capacity { get; set; }

            /// <summary>Minutos antes del inicio en que abre la puerta; null = valor de omisión.</summary>
            public int? doorOpensMinutes { get; set; }

            /// <summary>Minutos después del inicio en que cierran puerta y reserva (15 a 360).</summary>
            public int? doorClosesMinutes { get; set; }
        }

        public class CreateSpecialServiceResponseBag
        {
            public int resultCode { get; set; }
            public string message { get; set; }
            public string scheduleName { get; set; }
            public string occurrenceDate { get; set; }
        }

        public class GenerateItemBag
        {
            public int scheduleId { get; set; }
            public int capacity { get; set; }
        }

        public class GenerateRequestBag
        {
            public int campusId { get; set; }
            public string startDate { get; set; }
            public string endDate { get; set; }
            public List<GenerateItemBag> items { get; set; }
            public bool overwriteCapacity { get; set; }
            public bool deactivateOthers { get; set; }
        }

        public class GenerateResponseBag
        {
            public int inserted { get; set; }
            public int updated { get; set; }
            public int reactivated { get; set; }
            public int deactivated { get; set; }
            public int skippedLowCapacity { get; set; }
            public int skippedSpecialDay { get; set; }
            public List<string> warnings { get; set; }
        }

        public class UpdateSlotRequestBag
        {
            /// <summary>Minutos antes del inicio en que abre la puerta para este cupo (0 a 180).</summary>
            public int? doorOpensMinutes { get; set; }

            /// <summary>Minutos después del inicio en que cierran puerta y reserva; null = valor de omisión.</summary>
            public int? doorClosesMinutes { get; set; }

            /// <summary>true = volver al valor de omisión (NULL en la columna).</summary>
            public bool resetDoorToDefault { get; set; }

            public int slotId { get; set; }
            public int? capacity { get; set; }
            public bool? isActive { get; set; }
        }

        public class UpdateSlotResponseBag
        {
            public int resultCode { get; set; }
            public string message { get; set; }
        }

        private class SlotRow
        {
            public int SlotId { get; set; }
            public DateTime OccurrenceDate { get; set; }
            public int ScheduleId { get; set; }
            public string ScheduleName { get; set; }
            public int Capacity { get; set; }
            public int ReservedCount { get; set; }
            public int HoldCount { get; set; }
            public bool IsActive { get; set; }
        }

        /// <summary>
        /// Fila del listado de GetSlots: SlotRow + personas ingresadas. Es un tipo
        /// aparte a propósito: Generate y UpdateSlot también materializan SlotRow con
        /// un SELECT que no trae CheckedInCount, y EF6 exige que toda propiedad tenga
        /// su columna ("data reader is incompatible"). Agregar la columna a SlotRow
        /// rompía esas dos acciones.
        /// </summary>
        private class SlotListRow : SlotRow
        {
            public int CheckedInCount { get; set; }
            public bool IsSpecial { get; set; }
            public string ICalendarContent { get; set; }
            public int DoorOpensMinutes { get; set; }
            public int DoorClosesMinutes { get; set; }
            public bool DoorIsCustom { get; set; }
        }

        /// <summary>Fila de <see cref="LoadSlotTimes"/>. Tipo propio: no reutilizar SlotRow (ver arriba).</summary>
        private class SlotTimeRow
        {
            public int SlotId { get; set; }
            public DateTime OccurrenceDate { get; set; }
            public string ScheduleName { get; set; }
            public string ICalendarContent { get; set; }
            public bool IsActive { get; set; }
            public bool IsSpecial { get; set; }
        }

        private class MetricsSlotRow
        {
            public int SlotId { get; set; }
            public DateTime OccurrenceDate { get; set; }
            public int ScheduleId { get; set; }
            public string ScheduleName { get; set; }
            public int Capacity { get; set; }
            public int ReservedPeople { get; set; }
            public int CheckedInPeople { get; set; }
        }

        public class ScheduleMetricsBag
        {
            public int scheduleId { get; set; }
            public string scheduleName { get; set; }
            public int capacity { get; set; }
            public int reserved { get; set; }
            public int checkedIn { get; set; }
            public int noShow { get; set; }
            public int pending { get; set; }
            public bool isPast { get; set; }
        }

        public class WeekMetricsBag
        {
            public string weekStart { get; set; }
            public string sundayDate { get; set; }
            public string label { get; set; }
            public bool isPast { get; set; }
            public int capacity { get; set; }
            public int reserved { get; set; }
            public int checkedIn { get; set; }
            public int noShow { get; set; }
            public int pending { get; set; }
            public List<ScheduleMetricsBag> schedules { get; set; }
        }

        public class WeeklyMetricsResponseBag
        {
            public List<WeekMetricsBag> weeks { get; set; }
        }

        private class ScheduleCapacityRow
        {
            public int ScheduleId { get; set; }
            public int Capacity { get; set; }
        }

        #endregion
    }
}
