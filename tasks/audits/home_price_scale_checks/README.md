# PPML and dollar predictions from log prices

These two checks use the 2008–2018 half-mile single-family comparison, with
11,202 complete-characteristics transactions. They leave the packet and its
sample definitions unchanged. Run `make` from `code/`.

The first check estimates price levels by PPML with a log conditional mean,
using the same school-site and year fixed effects and the same property controls
as the existing OLS event studies. It also compares pooled 2008–2012 versus
2014–2018 DiDs, omitting 2013. All models give transactions equal weight and
cluster intervals by school site. PPML coefficients concern proportional changes
in conditional mean prices; OLS log coefficients concern conditional log prices.
Their difference alone does not identify a right-tail composition mechanism.

The second check exponentiates fitted log prices and multiplies by the sample
mean of exponentiated residuals (Duan smearing). This estimates dollar means
under a common residual retransformation factor, an assumption that can fail
with heteroskedasticity. A sensitivity uses separate treated/control factors
estimated from pre-2013 residuals and held fixed over time. We do not fit a
separate factor to each group-year, which would use the very mean gaps being
examined. All reconstructions are in-sample diagnostics, not causal validation.

Compare observed and predicted annual mean dollar gaps. Then run the original
levels regression on the dollar predictions, so its event coefficients can be
compared directly with the observed levels coefficients. A second prediction
sets the fitted treatment-year terms to zero while preserving site effects,
year effects, and observed properties. Its dollar projection shows how much
of the additive levels pattern can arise without differential log-price changes.
We also save the direct predicted dollar contrast from those treatment terms.
Prediction curves are point estimates; they have no estimated uncertainty bands.

The task reads the exact packet IDs, corrected sales, CPI, school exposures,
and saved original event coefficients. It verifies the sample and reproduces
all four original OLS event series. `scale_checks.rds` holds coefficients,
transaction predictions, annual gaps, reconstruction metrics, and smearing
factors; its standard report is written when the data are saved. `scale_checks.pdf`
and its three PNG figures present both checks.

Methods: [Santos Silva and Tenreyro (2006)](https://personal.lse.ac.uk/tenreyro/lgw.html)
and [Duan (1983)](https://doi.org/10.1080/01621459.1983.10478017).

## September 15 results

With property controls, the pooled 2014–2018 versus 2008–2012 PPML estimate
is 2.06% (95% interval −7.61% to 12.74%); the OLS-log coefficient transforms
to 2.98% (−12.20% to 20.77%). Dollar OLS estimates $34,851
(−$18,377 to $88,079). The PPML result does not show a strong positive
conditional-mean effect missing from logs. All use 10,159 sales after omitting
2013. The annual models include 2013 and use 11,202 sales.

For 2018 relative to 2012, the controlled levels coefficient is $33,344.
Applying that same levels regression to retransformed fitted log prices gives
$38,724, or $40,443 with fixed pre-period group smearing factors. Across the
five post years, the main reconstruction reduces squared error relative to
zero event coefficients by 65%; this is an in-sample reconstruction metric,
not an R-squared or a fraction of a causal effect. It misses some yearly moves.
The raw 2018 mean gap is $76,475 versus a predicted $99,140.

Setting the log treatment-year terms to zero produces an even larger 2018
levels projection ($104,145). Keeping them implies a negative direct 2018
contrast of about $58,067 among treated sales. Thus a positive additive levels
coefficient need not represent positive differential proportional appreciation.
Baseline price differences, common proportional growth, observed sale mix,
and the functional form of controls can generate dollar gaps. Neither this
reconstruction nor disagreement across estimators by itself identifies the
right tail or transaction composition as the causal mechanism.
