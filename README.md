# Olist E-Commerce Sales Analysis (SQL)

A SQL analysis of **~96,000 delivered orders** from Olist, a Brazilian e-commerce marketplace (Sept 2016 – Aug 2018), exploring what drives revenue, how delivery performance affects customer satisfaction, and why so few customers return.

<!-- Dashboard image: uncomment the line below once dashboard.png is uploaded -->
<!-- ![Dashboard](dashboard.png) -->

## Business questions
1. How big is the business: orders, customers, products and revenue?
2. How has revenue changed month by month?
3. Which product categories and states generate the most revenue?
4. Which payment methods do customers use?
5. **Do late deliveries lead to worse reviews?**
6. **How many customers come back, and who are the most valuable?**

## Key findings

| Metric | Value |
|---|---|
| Delivered orders | 96,478 |
| Unique customers | 93,358 |
| Products sold | 32,216 |
| Revenue (product sales, excl. delivery) | R$ 13.2M |
| Repeat customers | **3.0%** |

### 1. Late deliveries destroy customer satisfaction
- Late orders average **2.27 stars**, compared with **4.29** for on-time orders.
- **62% of late orders receive a 1–2 star review**, against **9%** of on-time orders, so late orders are about **7× more likely** to get a bad review.
- Only ~7% of orders arrive late (6,381 of 95,824), but they account for a large share of dissatisfied customers.

### 2. Olist has a serious retention problem
- **97% of customers bought only once.** Just 2,801 of 93,358 placed a second order.
- The top 10 customers together account for only **~0.5% of revenue**, and 9 of them ordered just once.
- Revenue growth depends almost entirely on acquiring new customers.

### 3. High-value customers drive almost half the revenue
Customers were segmented using an adapted **RFM** model (Recency and Monetary scores, with repeat buyers as a separate group).

| Segment | % of customers | Avg spend | % of revenue |
|---|---|---|---|
| High value – recent | 10.5% | R$ 303 | 22.4% |
| High value – at risk | 10.3% | R$ 310 | 22.6% |
| Middle | 32.3% | R$ 133 | 30.2% |
| Recent – low/mid spend | 21.8% | R$ 63 | 9.6% |
| Lost – low/mid spend | 22.1% | R$ 61 | 9.5% |
| Repeat buyers | 3.0% | R$ 260 | 5.5% |

- The two high-value segments are **21% of customers but 45% of revenue**.
- **9,652 "at risk" high-value customers** (average spend R$ 310, no purchase in ~15 months) represent **22.6% of revenue**, the clearest win-back opportunity.
- Repeat buyers spend about **2× the average customer**.

### 4. Sales trends, categories and regions
- **Growth:** monthly revenue roughly **doubled** between mid-2017 and 2018, then levelled off at R$ 0.85–0.98M per month.
- **Black Friday:** November 2017 was the peak month (7,289 orders, R$ 988k), with orders up **63%** on October.
- **Categories:** *Health & beauty* is the top category (R$ 1.23M). *Watches & gifts* ranks 2nd with fewer orders but the highest value per order (~R$ 212). The top 10 categories make up ~62% of revenue.
- **Regions:** São Paulo accounts for **42% of customers and 38% of revenue**; the top 3 states (SP, RJ, MG) generate ~63%. SP has the *lowest* revenue per customer in the top 10 (R$ 129), while Bahia has the highest (R$ 156).
- **Payments:** credit card is used in **77%** of orders (averaging 3.5 instalments), followed by *boleto* (bank slip) at 20%.

## Recommendations
1. **Reduce late deliveries:** more accurate delivery estimates, seller performance targets and proactive delay notifications.
2. **Win back high-value "at risk" customers** with targeted offers.
3. **Encourage second purchases** from recent high-value customers (e.g. follow-up discounts), since repeat buyers spend twice as much.
4. **Investigate the link between delivery experience and retention**, as a likely reason so few customers return.

## Approach
- **Tool:** SQL (SQLite via DB Browser for SQLite)
- **Data preparation:** imported 7 related tables (orders, order items, customers, products, payments, reviews, category translation); analysed **delivered orders only** (97% of all orders); used `customer_unique_id` to identify real repeat customers, since `customer_id` changes with every order; converted text fields to numbers with `CAST`; and handled missing delivery dates and untranslated categories.
- **SQL techniques used:**
  - Multi-table `JOIN`s and `LEFT JOIN`s
  - Aggregations (`SUM`, `COUNT DISTINCT`, `AVG`) with `GROUP BY`
  - Common Table Expressions (`WITH`), including a chain of four CTEs for RFM
  - Window functions (`NTILE() OVER`) for customer scoring
  - `CASE WHEN` for classification (late vs on-time, customer segments)
  - Subqueries for percentage-of-total calculations
  - Date functions (`strftime`, `julianday`, `date`)

## Limitations
- The dataset covers Sept 2016 – Aug 2018; months at both ends are partial.
- Revenue uses product price only and excludes delivery fees.
- Payment-method analysis covers all orders; some orders use more than one method, so percentages sum to slightly over 100%.
- RFM segments use equal thirds (`NTILE(3)`); different thresholds would change segment sizes.

## Files
- `olist_analysis.sql`: all queries, with results and insights as comments
- `results/`: exported query results (CSV)

## Data source
[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle, CC BY-NC-SA 4.0). Values are in Brazilian reais (R$). Customer data in the dataset is anonymised.

## Author
**Zufishaa Ayub**, 
[LinkedIn](http://linkedin.com/in/zufishaa-ayub-19b515248) · [GitHub](https://github.com/zufishaa)
