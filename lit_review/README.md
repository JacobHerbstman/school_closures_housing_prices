# School closures, neighborhoods, and housing markets

This folder contains the materials shared in the Noah Liu Slack conversation that are most relevant to the project, plus two underlying papers recovered from public links. The `*.layout.txt` files are searchable text extractions of the PDFs. They are reading aids; the PDFs remain the authoritative versions.

## File guide

- `effects_of_public_school_closures_on_crime_chicago_2013.pdf` — Noli Brazil (2020), the paper associated with the attached Chicago map and the clean candidate-list comparison.
- `statchen_et_al_2026_school_closure_firearm_violence.pdf` — a new open-access paper linked in Slack. It studies firearm violence after the same closure wave but uses a different control strategy.
- `pearman_greene_2022_school_closures_gentrification_black_metropolis.pdf` — the main neighborhood-change paper cited in the shared review; added from the public ERIC manuscript.
- `equilibrium_effects_of_neighborhood_schools.pdf` — Han and Idoux (2025), on Seattle's return to neighborhood-based assignment and the resulting capitalization and sorting effects.
- `permanent_school_closures_housing_markets_neighborhood_change_literature_review.pdf` — the source-verified review shared in Slack. Its PDF metadata identifies it as a ChatGPT Deep Research report, so it is best treated as a research map rather than a citable empirical study.
- `closure_list_map.png` — the attached map. Gray schools were not on the February closure list; red schools were listed but remained open; black schools were listed and closed.

## The Chicago candidate-list design

Brazil (2020) provides the cleanest version of the design we discussed.

- In December 2012, CPS identified 330 under-enrolled schools as potentially at risk.
- In February 2013, CPS released a shorter list of 129 elementary schools that could close.
- In May 2013, the Board voted to close 49 schools. Brazil's analysis compares those schools with 79 schools on the February list that remained open, for an analysis sample of 128 schools after one exclusion.
- The identifying assumption is that, conditional on differences in pre-existing trends, schools on the final list that remained open provide the counterfactual path for schools that closed.

The design is attractive because it compares schools that had already passed through a common selection screen. Closed schools look very different from all other open CPS schools, but much more similar to listed schools that stayed open. Brazil documents balance in school and tract characteristics and similarity in pre-closure crime levels. The compressed decision process and subsequent five-year moratorium also help: the closure was a sharp common event, and the post-period was not repeatedly contaminated by later CPS closures.

Brazil does not estimate a simple two-group mean DiD. The paper builds a monthly 2008–2018 panel around the candidate schools, measures crime in 75-, 150-, 300-, and 450-meter buffers, and estimates negative-binomial count models with school-buffer fixed effects and month-by-year fixed effects. Treatment is decomposed into time-varying post-closure states: unchanged, merged, vacant, repurposed as a non-school, and repurposed as another school. Robustness checks add buffer-specific linear trends, use Poisson models, and vary the start of vacancy status.

The main substantive result is heterogeneous. Vacancy and non-school reuse are associated with short-lived, highly localized reductions in crime, while merging student populations is associated with persistent increases in nonviolent crime across wider radii. This is a warning against treating “closure” as one homogeneous treatment.

## What the other studies actually identify

The new Statchen et al. (2026) firearm-violence paper studies 45 buildings that became vacant, but it does **not** use only the rejected closure candidates as controls. Its potential control pool is 405 open public elementary schools. It applies energy-balancing inverse-probability weights using tract demographics, estimates a spatial two-way fixed-effects DiD for 2010–2019, and tests pre-period trend differences. It reports an approximately 9.9% increase in nearby shootings after vacancy and a 10.2% increase around buildings that remained vacant long term; results for reused buildings are not statistically distinguishable from zero. The authors explicitly limit the causal claim because closure selection may reflect unobserved, time-varying neighborhood conditions.

Pearman and Greene (2022) is the central neighborhood-change paper, but it also does **not** use the Chicago closure shortlist. It combines national school-closure records with tract-level Census/ACS data for 2000–2012. A neighborhood is treated if a traditional neighborhood school closed within one mile. The outcome is a binary gentrification measure combining growth in real housing values and an above-city increase in college-educated White residents. The specification is a linear probability model with baseline neighborhood and district controls, 1990–2000 neighborhood trends, and city fixed effects; it also includes a reverse-timing falsification check. It finds an approximately nine-percentage-point increase in gentrification among the most segregated Black neighborhoods and a relative decline of roughly 200 Black residents. This is important evidence on sorting and neighborhood change, but it is not a transaction-level design and does not exploit rejected closure candidates.

Han and Idoux (2025) is not a closure paper. Its relevance is methodological and economic. Seattle's 2010 reform made newly drawn elementary attendance boundaries binding after a period in which those boundaries had no assignment consequence. The paper compares transaction prices just across boundaries before and after the reform, with boundary-by-period fixed effects and house controls. That design isolates the capitalization of school access from persistent cross-boundary differences. By 2013–2015, a one-standard-deviation increase in neighborhood-school math scores raises prices by about 1.8%, and a one-standard-deviation increase in the school's White enrollment share raises prices by about 3.2%. The paper then models residential sorting and equilibrium housing-price responses.

## Implications for our home-price project

The cleanest starting design is a parcel-level event study centered on the February candidate list:

1. Define treated sites as schools on the February list that ultimately closed and primary comparison sites as schools on the same list that remained open. Schools never listed should be a secondary comparison or diagnostic group, not the preferred counterfactual.
2. Use the complete parcel universe around both groups. Estimate both log sale price among transactions and a sale hazard or transaction count with parcels as the denominator. A price-only sample can miss market thinning or compositional changes in which homes sell.
3. Separate the relevant dates: publication of the candidate list, final closure decision, end-of-school-year closure, and later reuse or demolition. The announcement may be the economically meaningful treatment date for prices.
4. Measure exposure both by distance rings and by former attendance boundaries. Distance captures the local site amenity; former assignment rights capture the loss of a neighborhood schooling option. Their difference helps distinguish a land-use effect from a school-access effect.
5. Treat vacancy, demolition, reuse, and welcoming-school assignment as post-treatment mechanisms, not baseline treatment definitions. Site disposition is selected and deserves a second-stage design after estimating the initial closure effect.
6. Plot pre-trends for prices, sales, foreclosure, vacancy, and neighborhood composition. Weighting or matching on candidate-school and neighborhood fundamentals can improve comparability, but it does not make the final CPS vote random.
7. Plan explicitly for interference. Welcoming schools and neighborhoods may be treated through student reassignment, and nearby school buffers can overlap.

The key research gap identified by the shared review appears real within the materials inspected: none of these papers estimates the effect of Chicago's 2013 mass closures on parcel-level sale prices and housing-market liquidity using the February candidate list. That is precisely the contribution available to this project.

## Core citations

- Brazil, Noli. 2020. “Effects of Public School Closures on Crime: The Case of the 2013 Chicago Mass School Closure.” *Sociological Science* 7:128–151. https://doi.org/10.15195/v7.a6
- Statchen, Thomas, Michael Desjardins, Elizabeth Wagner, Odis Johnson Jr., Elizabeth L. Tung, and Mudia Uzzi. 2026. “The 2013 Mass Public School Closure and Firearm Violence in Chicago: A Quasi-Experimental Difference-in-Differences Analysis.” *Social Science & Medicine* 403:119428. https://doi.org/10.1016/j.socscimed.2026.119428
- Pearman, Francis A. II, and Danielle Marie Greene. 2022. “School Closures and the Gentrification of the Black Metropolis.” *Sociology of Education* 95(3):233–253. https://doi.org/10.1177/00380407221095205
- Han, Raymond, and Clemence Idoux. 2025. “Equilibrium Effects of Neighborhood Schools.” Job market paper, November 12, 2025 version.
