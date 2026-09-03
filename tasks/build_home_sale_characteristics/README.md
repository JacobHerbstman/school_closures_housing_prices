# Build home-sale characteristics

This task attaches Assessor improvement characteristics to the master
non-condominium transaction universe before market-sale cleaning. Its unit
remains one transaction, uniquely identified by `row_id`.

The Assessor source can contain multiple physical improvement cards for one
PIN-year. The task records the card count but attaches improvement
characteristics only for single-card PIN-years. It does not choose a primary
building or aggregate multiple buildings.

`single_improvement_card` identifies transactions for which the attached
characteristics describe one physical improvement. The output remains broad;
`correct_home_sale_characteristics` next applies historical exemption updates
and resolves analysis property type. Only then does `clean_home_sales` apply
study-period, market-sale, class, core-hedonic, and integrity restrictions.

Run `make` from this task's `code/` directory.
