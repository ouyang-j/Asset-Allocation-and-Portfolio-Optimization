# Multi-Stage Asset Allocation and Portfolio Optimization: The $100M Foundation Campaign

## Project Overview
[cite_start]This project focuses on developing a 10-year strategic asset allocation model for a 90-year-old foundation[cite: 6, 22]. [cite_start]The objective is to grow the foundation's assets from $40 million to $100 million by its centennial anniversary while managing annual spending and donation inflows[cite: 7, 8].

## The Challenge
The foundation faces a complex optimization problem:
* [cite_start]**Horizon:** 10-year investment period[cite: 7].
* [cite_start]**Cash Flows:** Pre-determined annual spending (~10% of assets) and community donations[cite: 11, 12].
* [cite_start]**Wealth Targets:** A $100 million target with a highly non-linear, piecewise utility function[cite: 17, 23].
* [cite_start]**Bequest Risk:** Modeling the immediate impact of large estate gifts ($12M total) from two major donors[cite: 15, 16].

## Methodology & Techniques
### 1. Stochastic Return Modeling
[cite_start]Market outcomes for seven asset classes—including US Stocks, Emerging Markets, and Hedge Funds—were modeled as a **jointly lognormal distribution**[cite: 28, 30]. 
* [cite_start]**Statistics:** Used multivariate normal distributions for continuously compounded returns: $ln(1+returns)$[cite: 31].
* [cite_start]**Asset Mixes:** Evaluated seven distinct portfolios ranging from conservative (Mix 1) to aggressive (Mix 7)[cite: 28].

### 2. Optimization Objective
[cite_start]The model maximizes the **Expected Utility of Wealth** at the 10-year horizon ($W_{10}$)[cite: 24, 46]. The utility function is defined across four distinct psychological ranges:

* **Very Successful ($W > \$110M$):** $U(W) = 5.80 \frac{W^{0.5}-1}{0.5}$
* **Successful ($\$100M - \$110M$):** $U(W) = W$
* **Somewhat Disappointing ($\$95M - \$100M$):** $U(W) = 1.01 \cdot (W - e^{-0.001 \cdot (100-W)})$
* **Very Disappointing ($W < \$95M$):** $U(W) = W - 0.2(95-W)^2$
[cite_start][cite: 23]

### 3. Solution Approach
[cite_start]I implemented a **recursive relationship between stages** to determine the optimal investment strategy at each yearly interval[cite: 46]. [cite_start]This allows the foundation to dynamically switch asset mixes in response to market performance[cite: 25].

## Technologies Used
* **R:** Core engine for stochastic simulation and optimization.
* **R Markdown:** Used for generating the comprehensive technical report.
* **LaTeX:** For typesetting mathematical formulations and utility functions.

## Key Insights
* [cite_start]**Likelihood of Success:** Determined the probability of reaching the $100M threshold under various market scenarios[cite: 34].
* [cite_start]**Strategy Evolution:** Identified how the optimal asset mix shifts from aggressive to conservative as the foundation approaches its target wealth[cite: 40].
* [cite_start]**Sensitivity Analysis:** Analyzed the impact of Donor A and Donor B’s bequests on the long-term probability of success[cite: 41].
