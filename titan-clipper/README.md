# Titan Clipper

Titan Clipper is a personal revenue-operations engine designed to turn scattered opportunities into a disciplined, compounding business pipeline.

It prioritizes four revenue lanes that fit Hub City's current assets:

1. Partner Path Logistics — medical courier contracts.
2. Operations work / consulting — logistics, dispatch, DOT/HOS, and fleet operations.
3. Inventory sales — repeat B2B snack, candy, and energy-product orders.
4. Hub City Media — content-led promotion and local business campaigns.

## Current capabilities

- import leads from a normal CSV;
- score leads by recurring revenue potential, fit, urgency, and contact quality;
- generate lane-specific outreach drafts;
- queue follow-ups;
- maintain an approval queue and revenue dashboard;
- record outcomes so future cycles focus on what converts.

## Control model

Titan Clipper drafts work and organizes the queue; the founder approves reputation-, money-, and contract-sensitive actions.

## Start

```bash
python titan_clipper.py --db data/titan.sqlite init
python titan_clipper.py --db data/titan.sqlite import-leads leads.example.csv
python titan_clipper.py --db data/titan.sqlite run-cycle
python titan_clipper.py --db data/titan.sqlite dashboard
```

See `docs/OPERATING_MODEL.md` for the operating rules.