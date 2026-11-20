/** Desactivar/Reactivar desde la lista del rango: refresca también el planificador. */
async function toggleFromList(slot: SlotBag): Promise<void> {
    await toggleActive(slot);
    void loadSpecialDay();
    void loadUpcomingSpecials();
}

/** Desactivar/Reactivar desde el planificador del día: refresca la lista del rango y los próximos especiales. */
async function toggleFromSpecialDay(slot: SlotBag): Promise<void> {
    await toggleActive(slot);
    void loadSpecialDay();
    void loadUpcomingSpecials();
    void loadSlots(false);
}

/** Desactivar/Reactivar desde «Próximos servicios especiales». */
async function toggleFromUpcoming(slot: SlotBag): Promise<void> {
    await toggleActive(slot);
    void loadSpecialDay();
    void loadUpcomingSpecials();
    void loadSlots(false);
}

// ---- Planificar un día ----
// Los valores vienen del servidor (SundayServiceCapacityAdmin.cs), que además vuelve a
// validar todo; aquí solo sirven para mostrar y avisar antes de pulsar.
const defaultDoor = config.defaultDoorOpensMinutes || 15;
const maxDoor = config.maxDoorOpensMinutes || 180;
const closesAfter = config.doorClosesMinutes || 80;
const registrationWindowDays = config.registrationWindowDays || 7;
const todayIso = config.todayIso || toIso(new Date());
const closesAfterText = closesAfter % 60 === 0
    ? `${closesAfter / 60} h`
    : `${Math.floor(closesAfter / 60)} h ${closesAfter % 60} min`;

/** Cupo del planificador: igual que en la lista, más el borrador de la apertura de la puerta. */
type DaySlot = SlotBag & { draftDoor: number };

const plannerCard = ref<HTMLElement | null>(null);
const specialDate = ref<string>("");
const specialTime = ref<string>("");
const specialName = ref<string>("");
const specialCapacity = ref<number>(0);
const specialDoor = ref<number>(defaultDoor);
const specialBusy = ref<boolean>(false);
const specialResult = ref<{ kind: "success" | "warning"; message: string } | null>(null);
const specialDaySlots = ref<DaySlot[]>([]);
const specialDayBusy = ref<boolean>(false);
let specialDayRequest = 0;

function timeToMinutes(t: string): number | null {
    const m = /^(\d{1,2}):(\d{2})/.exec(t || "");
    return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

function minutesToText(min: number): string {
    const n = ((min % 1440) + 1440) % 1440;
    return `${Math.floor(n / 60)}:${String(n % 60).padStart(2, "0")}`;
}

function longDate(d: Date): string {
    return d.toLocaleDateString("es-GT", { weekday: "long", day: "numeric", month: "long" });
}

function isValidDoor(v: unknown): v is number {
    return typeof v === "number" && Number.isInteger(v) && v >= 0 && v <= maxDoor;
}

/** «13:45 a 15:20»: ventana de la puerta de un servicio que empieza a `timeText`. */
function doorRangeText(timeText: string, doorMinutes: number): string {
    const start = timeToMinutes(timeText);
    if (start === null) {
        return "";
    }
    const door = isValidDoor(doorMinutes) ? doorMinutes : defaultDoor;
    return `${minutesToText(start - door)} a ${minutesToText(start + closesAfter)}`;
}

const plannerDateLong = computed<string>(() => {
    const d = parseIso(specialDate.value);
    if (!d) {
        return "";
    }
    const text = longDate(d);
    return text.charAt(0).toUpperCase() + text.slice(1);
});

const specialMinutes = computed<number | null>(() => timeToMinutes(specialTime.value));
const specialNameHasTime = computed<boolean>(() => /\d{1,2}\s*:\s*\d{2}/.test(specialName.value || ""));

const specialFinalName = computed<string>(() => {
    const label = (specialName.value || "").trim() || "Servicio especial";
    return specialMinutes.value === null ? label : `${label} ${minutesToText(specialMinutes.value)} h`;
});

// ---- Línea de tiempo del día ----

type TimelineItem = { key: string; name: string; active: boolean; special: boolean; preview: boolean; start: number; open: number; close: number };

/** Servicios del día (con la apertura en borrador, para ver el cambio antes de guardar) y el especial nuevo. */
const timelineItems = computed<TimelineItem[]>(() => {
    const items: TimelineItem[] = [];

    for (const s of specialDaySlots.value) {
        const start = timeToMinutes(s.timeText);
        if (start === null) {
            continue;
        }
        const door = isValidDoor(s.draftDoor) ? s.draftDoor : s.doorOpensMinutes;
        items.push({ key: `s${s.slotId}`, name: s.scheduleName, active: s.isActive, special: s.isSpecial, preview: false, start, open: start - door, close: start + closesAfter });
    }

    if (specialMinutes.value !== null) {
        const door = isValidDoor(specialDoor.value) ? specialDoor.value : defaultDoor;
        items.push({ key: "new", name: `${specialFinalName.value} (nuevo)`, active: true, special: true, preview: true, start: specialMinutes.value, open: specialMinutes.value - door, close: specialMinutes.value + closesAfter });
    }

    return items.sort((a, b) => a.start - b.start);
});

/** Eje de la línea de tiempo: horas completas con 30 min de margen. */
const timelineRange = computed<{ min: number; max: number } | null>(() => {
    const items = timelineItems.value;
    if (items.length === 0) {
        return null;
    }
    const min = Math.floor((Math.min(...items.map(i => i.open)) - 30) / 60) * 60;
    const max = Math.ceil((Math.max(...items.map(i => i.close)) + 30) / 60) * 60;
    return { min, max: Math.max(max, min + 120) };
});

const timelineTicks = computed<Array<{ label: string; left: number }>>(() => {
    const r = timelineRange.value;
    if (!r) {
        return [];
    }
    const span = r.max - r.min;
    const step = span > 12 * 60 ? 120 : 60;
    const ticks: Array<{ label: string; left: number }> = [];
    for (let t = r.min; t <= r.max; t += step) {
        ticks.push({ label: minutesToText(t), left: ((t - r.min) / span) * 100 });
    }
    return ticks;
});

const timelineRows = computed(() => {
    const r = timelineRange.value;
    if (!r) {
        return [];
    }
    const span = r.max - r.min;
    return timelineItems.value.map(i => ({
        key: i.key,
        name: i.name,
        active: i.active,
        special: i.special,
        preview: i.preview,
        left: ((i.open - r.min) / span) * 100,
        width: ((i.close - i.open) / span) * 100,
        startPct: ((i.start - i.open) / (i.close - i.open)) * 100,
        hoursText: `${minutesToText(i.open)}–${minutesToText(i.close)}`,
        title: `Puerta de ${minutesToText(i.open)} a ${minutesToText(i.close)} · inicio ${minutesToText(i.start)}`
    }));
});

/** ¿Dos ventanas activas se cruzan? Solo informativo: la puerta valida cada QR con su propio servicio. */
const hasOverlap = computed<boolean>(() => {
    const active = timelineItems.value.filter(i => i.active).sort((a, b) => a.open - b.open);
    for (let i = 1; i < active.length; i++) {
        if (active[i].open < active[i - 1].close) {
            return true;
        }
    }
    return false;
});

const specialDateInRange = computed<boolean>(() =>
    !!specialDate.value && specialDate.value >= startDate.value && specialDate.value <= endDate.value);

/** Minutos desde medianoche según el reloj del equipo; solo para avisar «ya pasó». */
function nowMinutesLocal(): number {
    const n = new Date();
    return n.getHours() * 60 + n.getMinutes();
}

const specialDoorAllowed = computed<boolean>(() =>
    isValidDoor(specialDoor.value) && (config.doorColumnReady || specialDoor.value === defaultDoor));

const specialCanCreate = computed<boolean>(() =>
    !!campusId.value
    && !!parseIso(specialDate.value)
    && specialDate.value >= todayIso
    && specialMinutes.value !== null
    && Number(specialCapacity.value) > 0
    && !specialNameHasTime.value
    && specialDoorAllowed.value
    && !specialDayBusy.value);

const specialPreviewText = computed<string>(() => {
    const d = parseIso(specialDate.value);
    if (!campusId.value) {
        return "Selecciona una sede arriba.";
    }
    if (!d) {
        return "Elige la fecha en el paso 1.";
    }
    if (specialDate.value < todayIso) {
        return "Esa fecha ya pasó.";
    }
    if (specialMinutes.value === null) {
        return "Indica la hora de inicio.";
    }
    if (specialDate.value === todayIso && specialMinutes.value + closesAfter <= nowMinutesLocal()) {
        return "Esa hora ya pasó.";
    }
    if (specialNameHasTime.value) {
        return "Quita la hora del nombre: se agrega sola.";
    }
    if (!(Number(specialCapacity.value) > 0)) {
        return "Indica la capacidad.";
    }
    if (!isValidDoor(specialDoor.value)) {
        return `La puerta puede abrir entre 0 y ${maxDoor} min antes.`;
    }
    if (!specialDoorAllowed.value) {
        return `Para abrir distinto de ${defaultDoor} min falta preparar la base de datos (ver el aviso de arriba).`;
    }

    const opens = new Date(d.getTime());
    opens.setDate(opens.getDate() - (registrationWindowDays - 1));
    const opensText = toIso(opens) <= todayIso ? "en cuanto lo crees" : `desde el ${longDate(opens)}`;
    const door = doorRangeText(minutesToText(specialMinutes.value), specialDoor.value);

    return `Se publicará como «${specialFinalName.value}» con ${specialCapacity.value} lugares. Se podrá reservar ${opensText} y la puerta leerá los QR de ${door}.`;
});

/** Carga los servicios de la fecha elegida (activos y desactivados). */
async function loadSpecialDay(): Promise<void> {
    const request = ++specialDayRequest;

    if (!campusId.value || !parseIso(specialDate.value)) {
        specialDaySlots.value = [];
        specialDayBusy.value = false;
        return;
    }

    specialDayBusy.value = true;

    try {
        const res = await invokeBlockAction<{ days: DaySlotsBag[] }>("GetSlots", {
            bag: { campusId: campusId.value, startDate: specialDate.value, endDate: specialDate.value }
        });

        if (request !== specialDayRequest) {
            return;
        }

        const slots: DaySlot[] = [];
        for (const d of (res.isSuccess && res.data ? res.data.days || [] : [])) {
            for (const s of d.slots || []) {
                slots.push({ ...s, draftCapacity: s.capacity, draftDoor: s.doorOpensMinutes });
            }
        }
        slots.sort((a, b) => (timeToMinutes(a.timeText) ?? 9999) - (timeToMinutes(b.timeText) ?? 9999));
        specialDaySlots.value = slots;
    }
    catch {
        if (request === specialDayRequest) {
            specialDaySlots.value = [];
        }
    }
    finally {
        if (request === specialDayRequest) {
            specialDayBusy.value = false;
        }
    }
}

watch([campusId, specialDate], () => {
    specialResult.value = null;
    void loadSpecialDay();
});

/** Abre el planificador en una fecha (desde la lista del rango o los próximos especiales). */
function planDay(dateIso: string): void {
    specialDate.value = dateIso;
    void nextTick(() => plannerCard.value?.scrollIntoView({ behavior: "smooth", block: "start" }));
}

function showSpecialDateInList(): void {
    if (specialDate.value) {
        startDate.value = specialDate.value;
        endDate.value = specialDate.value;
    }
}

/** Guarda la apertura de la puerta de un cupo. Igual al valor de omisión = vuelve a «normal». */
async function saveDoor(slot: DaySlot): Promise<void> {
    if (rowBusy.value) {
        return;
    }

    const value = Number(slot.draftDoor);
    if (!isValidDoor(value)) {
        showToast("danger", `La puerta puede abrir entre 0 y ${maxDoor} min antes.`);
        slot.draftDoor = slot.doorOpensMinutes;
        return;
    }

    await updateDoor(slot, value === defaultDoor ? { resetDoorToDefault: true } : { doorOpensMinutes: value });
}

async function resetDoor(slot: DaySlot): Promise<void> {
    if (rowBusy.value) {
        return;
    }
    await updateDoor(slot, { resetDoorToDefault: true });
}

async function updateDoor(slot: DaySlot, change: { doorOpensMinutes?: number; resetDoorToDefault?: boolean }): Promise<void> {
    rowBusy.value = slot.slotId;
    try {
        const res = await invokeBlockAction<{ resultCode: number; message: string }>("UpdateSlot", {
            bag: { slotId: slot.slotId, ...change }
        });

        if (res.isSuccess && res.data?.resultCode === 1) {
            const value = change.resetDoorToDefault ? defaultDoor : (change.doorOpensMinutes ?? defaultDoor);
            slot.doorOpensMinutes = value;
            slot.draftDoor = value;
            slot.doorIsCustom = !change.resetDoorToDefault;
            showToast("success", `La puerta abrirá ${value} min antes.`);
            void loadSlots(false);
            void loadUpcomingSpecials();
        }
        else {
            slot.draftDoor = slot.doorOpensMinutes;
            showToast("danger", res.data?.message || res.errorMessage || "No se pudo guardar.");
        }
    }
    catch {
        slot.draftDoor = slot.doorOpensMinutes;
        showToast("danger", "Error guardando la apertura de la puerta.");
    }
    finally {
        rowBusy.value = 0;
    }
}

async function createSpecial(): Promise<void> {
    if (specialBusy.value || !specialCanCreate.value) {
        return;
    }

    specialBusy.value = true;
    specialResult.value = null;

    try {
        const res = await invokeBlockAction<{ resultCode: number; message: string; scheduleName: string; occurrenceDate: string }>("CreateSpecialService", {
            bag: {
                campusId: campusId.value,
                date: specialDate.value,
                time: specialTime.value,
                name: (specialName.value || "").trim(),
                capacity: Number(specialCapacity.value),
                doorOpensMinutes: specialDoor.value === defaultDoor ? null : specialDoor.value
            }
        });

        if (res.isSuccess && res.data?.resultCode === 1) {
            specialResult.value = { kind: "success", message: res.data.message };
            specialTime.value = "";
            specialName.value = "";
            specialDoor.value = defaultDoor;
            showToast("success", "Servicio especial creado.");
        }
        else {
            specialResult.value = { kind: "warning", message: res.data?.message || res.errorMessage || "No se pudo crear el servicio especial." };
        }
    }
    catch {
        specialResult.value = { kind: "warning", message: "Error creando el servicio especial." };
    }
    finally {
        specialBusy.value = false;
        void loadSpecialDay();
        void loadUpcomingSpecials();
        void loadSlots(false);
    }
}

// ---- Próximos servicios especiales ----

type UpcomingSpecialBag = SlotBag & { occurrenceDate: string; occurrenceDateText: string };

const upcomingSpecials = ref<UpcomingSpecialBag[]>([]);
const upcomingBusy = ref<boolean>(false);
let upcomingRequest = 0;

/** Servicios especiales del campus desde hoy. */
async function loadUpcomingSpecials(): Promise<void> {
    const request = ++upcomingRequest;

    if (!campusId.value) {
        upcomingSpecials.value = [];
        upcomingBusy.value = false;
        return;
    }

    upcomingBusy.value = true;

    try {
        const res = await invokeBlockAction<UpcomingSpecialBag[]>("GetUpcomingSpecialServices", {
            bag: { campusId: campusId.value, startDate: todayIso, endDate: todayIso }
        });

        if (request === upcomingRequest) {
            upcomingSpecials.value = res.isSuccess && res.data ? res.data.map(s => ({ ...s, draftCapacity: s.capacity })) : [];
        }
    }
    catch {
        if (request === upcomingRequest) {
            upcomingSpecials.value = [];
        }
    }
    finally {
        if (request === upcomingRequest) {
            upcomingBusy.value = false;
        }
    }
}

watch(campusId, () => {
    void loadUpcomingSpecials();
});

if (campusId.value) {
    void loadUpcomingSpecials();
}
