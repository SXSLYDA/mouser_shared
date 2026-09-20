# mouser-lookup

Framework-agnostic Mouser Electronics search + prefill mapping. No Django
dependency in the core — install it once, use it from both OMG Harness and
the InvenTree import plugin.

## Install

```bash
pip install -e /path/to/mouser_lookup
```

Do this in both environments — OMG Harness's venv, and InvenTree's venv (or
wherever the omg-harness-import plugin runs) — since each process imports
it independently; nothing is shared over HTTP between them.

## Core API

```python
from mouser_lookup import search_by_mpn, prefill

results = search_by_mpn("DT04-12PA", api_key="your-mouser-key")
# -> list of normalized dicts: mpn, spn, description, manufacturer, url,
#    image, datasheet, attributes, contact_count, gender,
#    conductor_size_min/max, outer_diameter, primary_color, secondary_color,
#    price_breaks, in_stock

# For creating a part directly in InvenTree:
payload = prefill.to_inventree_payload(results[0], category_pk=14)
# -> {'name': ..., 'IPN': ..., 'description': ..., 'category': 14, ...}
```

## Current usage

- **OMG side** (`omg/components_app/`): `search_by_mpn` backs the picker's
  Mouser tab and `pending_parts_views.py`'s Mouser search endpoint —
  results become a `PendingPart` (raw Mouser data stored as-is in
  `mouser_data`, no field-mapping needed at this stage) until the
  InvenTree plugin resolves it to a real Part.
- **InvenTree plugin side** (`inventree/omg_import_plugin/`):
  `mouser_supplier.py`'s `SupplierMixin` implementation and
  `resolve_pending.py` both use `prefill.to_inventree_payload()` — the
  only place Mouser data actually becomes a real InvenTree Part, using
  InvenTree's own field names.

(An earlier version of this package had a `prefill.to_omg_fields()`
function for a "materialize a searched part" flow tied to OMG's old
`components` app — `ConnectorPart`/`BootPart`/`ContactPart`/
`ConductorPart` models. That app was removed entirely; the function was
already unused by anything real and has been removed too, rather than
leaving dead code with documentation describing a system that no longer
exists.)

## Wiring it into the InvenTree plugin

This is the "easy part creation in InvenTree" half. Add a Mouser API key as
a plugin setting (`SETTINGS` dict in `core.py`, same pattern as
`AMBIGUOUS_SEARCH_LIMIT`), then a new endpoint:

```python
# omg_import_plugin/mouser_create.py
from mouser_lookup import search_by_mpn, prefill
from part.models import Part

def create_part_from_mpn(mpn, api_key, category_pk=None):
    candidates = search_by_mpn(mpn, api_key)
    if not candidates:
        return {"status": "not_found"}
    if len(candidates) > 1:
        # Let the caller choose — never auto-pick between multiple Mouser hits.
        return {"status": "multiple", "candidates": candidates}

    existing = Part.objects.filter(IPN__iexact=candidates[0]["mpn"]).first()
    if existing:
        return {"status": "already_exists", "part_pk": existing.pk}

    payload = prefill.to_inventree_payload(candidates[0], category_pk=category_pk)
    part = Part.objects.create(**payload)
    return {"status": "created", "part_pk": part.pk}
```

Expose that behind a `POST /plugin/omg-harness-import/mouser-create/`
endpoint (same pattern as `api.py`'s other views) taking
`{"mpn": "...", "category_pk": 14}`, with an optional `{"chosen_index": 0}`
on a follow-up call when `status == "multiple"`. This gives you the
"temporarily create + prefill" flow on the OMG side and "search Mouser,
create the InvenTree part directly" on the InvenTree side, from the same
underlying client and the same normalized result shape — no duplicated
Mouser-parsing logic in either place.

## Why this is separate from `components` and from the plugin

Neither OMG's `components` app nor the InvenTree plugin should have to
depend on the other to get Mouser data — they're separate Django projects
running in separate processes. A standalone pip-installable package is the
only way both sides use the identical parsing/normalization logic without
one importing the other's app.
