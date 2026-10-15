# FamilyHub Known Relationships Fix (Rock18)

> **Última actualización:** 2026-10-15 (revisión de traspaso). Estado: fix commiteado en abril 2026 (commit `2958358094`; ajustes de KR + batching en `4f80ff56b0`, 2026-05-13). El backend `FamilyHub.cs` no cambia desde 2026-06-06.
> **Nota:** la sección "UI refresh summary" está parcialmente obsoleta: el sticky top bar (`vrTopBar`) se eliminó el 2026-07-24. El historial vigente del bloque está en `Rock.Blocks/FamilyHub/CHANGES.md` (§7 y §8).

## Files changed
- `Rock.Blocks/FamilyHub/FamilyHub.cs` (renamed from `FamilyHub..cs`)
- `Rock.JavaScript.Obsidian.Blocks/src/FamilyHub/FamilyHub.obs`

## Backend fix summary
The `SaveKnownRelationshipFromMeToPerson(...)` flow now does all of this:

1. Normalizes forward role (`me -> other`) and rejects invalid/Owner role.
2. Ensures my Known Relationship group exists (and owner membership is active).
3. Upserts/removes forward relation in my group.
4. Resolves inverse role from GroupTypeRole attribute key `InverseRelationship`.
5. If inverse exists:
   - ensures other person's Known Relationship group exists,
   - upserts inverse relation (`other -> me`) in their group.
6. If inverse does not exist or role is removed:
   - removes stale inverse relation from the other person's group (if present).
7. Never assigns Owner as inverse relationship role.

## Scenarios covered
- Set relation with valid inverse: creates/updates both directions.
- Set relation where other person has no Known group: creates it + owner + inverse member.
- Remove relation (`roleId = null`): removes both forward and inverse.
- Invalid role or Owner role sent: treated as null (relationship removed), avoids bad writes.
- Existing incorrect inverse with no configured inverse now gets cleaned up.

## Build validation
- `dotnet build Rock.Blocks` passed.
- `npm run build:types` passed.
- `npm run build-fast` passed.

## UI refresh summary
`FamilyHub.obs` was redesigned using the same visual language used in `QREVENT/SundayServiceRegistration.obs`:
- sticky top bar (`vrPage` / `vrTopBar`),
- card-based member grid,
- cleaner edit modal with split form + photo area,
- improved phone picker UX,
- improved photo upload UX (preview + dedicated action + file hint).
