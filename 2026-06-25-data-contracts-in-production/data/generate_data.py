#!/usr/bin/env python3
"""Generate the e-commerce demo CSVs, reproducibly (seed=42).

    python3 generate_data.py --mode clean   --out ./clean    # no DQ issues
    python3 generate_data.py --mode failing --out ./failing  # planted DQ issues

Planted issues (failing mode) are the answer key in DATA_QUALITY_ISSUES.md.
"""
import argparse, csv, os, random
from datetime import date, timedelta

N_CUSTOMERS, N_PRODUCTS, N_ORDERS = 500, 120, 2000
START, END = date(2024, 1, 1), date(2025, 12, 31)

FIRST = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
         "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
         "Thomas", "Sarah", "Chen", "Wei", "Priya", "Aisha", "Mateo", "Sofia", "Liam",
         "Olivia", "Noah", "Emma", "Lucas", "Mia"]
LAST = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
        "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
        "Thomas", "Taylor", "Moore", "Jackson", "Lee", "Patel", "Nguyen", "Kim", "Singh"]
DOMAINS = ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "icloud.com", "proton.me"]
# inconsistent variants (failing) vs canonical set (clean)
COUNTRY_VARIANTS = ["US", "USA", "United States", "U.S.A.", "us", "UK", "United Kingdom", "GB",
                    "Canada", "CA", "canada", "Germany", "DE", "Deutschland", "France", "FR"]
CANONICAL_COUNTRIES = ["US", "UK", "Canada", "Germany", "France", "Australia"]
CATEGORIES = ["Electronics", "Home & Kitchen", "Books", "Clothing", "Toys", "Sports",
              "Beauty", "Garden", "Automotive", "Grocery"]
STATUSES = ["pending", "paid", "shipped", "delivered", "cancelled", "returned"]


def rand_date(start=START, end=END):
    return start + timedelta(days=random.randint(0, (end - start).days))


def slug(s):
    return "".join(c for c in s.lower() if c.isalnum())


def make_customers(clean):
    rows, used = [], set()
    countries = CANONICAL_COUNTRIES if clean else COUNTRY_VARIANTS
    for i in range(1, N_CUSTOMERS + 1):
        fn, ln = random.choice(FIRST), random.choice(LAST)
        while True:  # unique emails only matter for the clean set
            email = f"{slug(fn)}.{slug(ln)}{random.randint(1, 99)}@{random.choice(DOMAINS)}"
            if not clean or email not in used:
                break
        used.add(email)
        rows.append({
            "customer_id": i, "first_name": fn, "last_name": ln, "email": email,
            "phone": f"+1-{random.randint(200,999)}-{random.randint(200,999)}-{random.randint(1000,9999)}",
            "country": random.choice(countries), "age": random.randint(18, 78),
            "signup_date": rand_date(date(2022, 1, 1), END).isoformat(),
            "is_active": random.choice(["true", "false"]),
        })
    if clean:
        return rows
    for r in random.sample(rows, 15): r["email"] = ""                         # missing
    for r in random.sample(rows, 8): r["email"] = r["email"].replace("@", "_at_")  # invalid
    for r in random.sample(rows, 10): r["email"] = f"  {r['email'].upper()}  "     # whitespace/case
    nid = N_CUSTOMERS + 1
    for src in random.sample(rows, 6):                                        # duplicate customers
        rows.append({**src, "customer_id": nid, "signup_date": rand_date().isoformat()}); nid += 1
    for r, a in zip(random.sample(rows, 3), (-5, 0, 240)): r["age"] = a       # impossible ages
    for r in random.sample(rows, 5): r["age"] = ""                            # missing age
    for r in random.sample(rows, 12): r["phone"] = str(random.randint(2000000000, 9999999999))
    for r in random.sample(rows, 6): r["phone"] = ""
    for r in random.sample(rows, 4): r["is_active"] = ""                      # missing flag (NULL)
    random.choice(rows)["signup_date"] = "2027-06-15"                         # implausible future signup
    return rows


def make_products(clean):
    rows = []
    for i in range(1, N_PRODUCTS + 1):
        cat = random.choice(CATEGORIES)
        price = round(random.uniform(2.5, 950.0), 2)
        rows.append({
            "product_id": f"SKU-{i:04d}", "name": f"{cat} item {i}", "category": cat,
            "price": f"{price:.2f}", "cost": f"{price * random.uniform(0.4, 0.85):.2f}",
            "stock_quantity": random.randint(0, 500), "currency": "USD", "active": "true",
        })
    if clean:
        return rows
    random.choice(rows)["price"] = "-19.99"                                   # negative price
    random.choice(rows)["price"] = "0.00"                                     # zero price
    random.choice(rows)["price"] = "99999.99"                                 # implausible high outlier
    random.choice(rows)["price"] = "0.01"                                     # implausible low outlier
    for r in random.sample(rows, 5): r["currency"] = random.choice(["EUR", "GBP", "usd", ""])
    for r in random.sample(rows, 4): r["category"] = ""                       # missing category
    for r, c in zip(random.sample(rows, 3), ("electronics", "Home and Kitchen", " Books ")):
        r["category"] = c                                                     # casing/spelling
    random.choice(rows)["stock_quantity"] = -3                                # negative stock
    for r in random.sample(rows, 3): r["cost"] = "999.00"                     # cost > price
    rows.append({**random.choice(rows), "name": "Relisted"})                  # duplicate SKU
    rows.append({**random.choice(rows), "product_id": "", "name": "Mystery item"})  # null id
    return rows


def make_orders(clean, customer_ids):
    rows = []
    for i in range(1, N_ORDERS + 1):
        od = rand_date()
        status = random.choice(STATUSES)
        shipped = status in ("shipped", "delivered", "returned")
        rows.append({
            "order_id": f"ORD-{i:06d}", "customer_id": random.choice(customer_ids),
            "order_date": od.isoformat(),
            "ship_date": (od + timedelta(days=random.randint(1, 10))).isoformat() if shipped else "",
            "status": status, "total_amount": round(random.uniform(10, 2000), 2),
            "discount_pct": random.choice([0, 0, 0, 5, 10, 15, 20]),
        })
    if clean:
        return rows
    for r in random.sample(rows, 10): r["customer_id"] = random.randint(99000, 99999)  # orphan
    for r in random.sample(rows, 8):                                          # ship before order
        r["ship_date"] = (date.fromisoformat(r["order_date"]) - timedelta(days=2)).isoformat()
    for r in random.sample(rows, 12):                                         # implausible future order dates
        r["order_date"] = (END + timedelta(days=random.randint(15, 365))).isoformat()
    for r in random.sample(rows, 10):
        r["status"] = random.choice(["Delivered", "SHIPPED", "complete", "Refunded", "processing"])
    for r, t in zip(random.sample(rows, 3), (-250.0, 0, 9999999.99)): r["total_amount"] = t
    for r in random.sample(rows, 7): r["total_amount"] = ""                   # missing total
    random.choice(rows)["discount_pct"] = 150
    random.choice(rows)["discount_pct"] = -10
    rows.append(dict(random.choice(rows)))                                    # duplicate order_id
    return rows


def write_csv(out_dir, name, rows):
    with open(os.path.join(out_dir, name), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys())
        w.writeheader()
        w.writerows(rows)
    print(f"  {name:18s} {len(rows):6d} rows")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["clean", "failing"], required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    clean = args.mode == "clean"
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    random.seed(42)
    print(f"Generating '{args.mode}' dataset into {out}/")

    customers = make_customers(clean)
    products = make_products(clean)
    cids = [c["customer_id"] for c in customers if str(c["customer_id"]).strip()]
    orders = make_orders(clean, cids)

    write_csv(out, "customers.csv", customers)
    write_csv(out, "products.csv", products)
    write_csv(out, "orders.csv", orders)
    print("Done.")


if __name__ == "__main__":
    main()
