# Audit home-sale prices per square foot

This audit joins cleaned sales to the smallest useful extracts from Cook
County's residential-improvement and condominium-characteristics data. It
reports square-footage coverage and annual price-per-square-foot distributions,
and it preserves the lowest and highest observations for inspection.

The audit does not delete or winsorize sales. Any eventual production exclusion
must be limited to documented data-error regions identified here and encoded as
an explicit flag rather than by a rolling, treatment-dependent distribution.

House price per square foot is calculated only when the PIN-year has one
residential-improvement card. Condo price per square foot uses recorded unit
square footage. Both the total document price and the County-prorated condo-unit
price remain available for verified condo-and-parking sales.
