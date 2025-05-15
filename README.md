# dbt-certification-study-guide

This is a learning and experimentation dbt project based on the `jaffle_shop` example. It was designed to help me explore dbt core features, such as models, seeds, macros, testing, exposures, documentation, and advanced materializations, and prepare myself to the **dbt Analytics Engineering Certification Exam**. 

It contains all my notes and study material heavily based on dbt official courses.

---

## 🏗️ Project Structure

```
.
├── README.md
├── .gitignore
├── .git/                         # Git repository data
│
├── seeds/                        # Raw seed data (CSV)
│   └── jaffle_shop_raw/
│       ├── *.csv                # Raw input data
│       └── *_seeds.yml          # Metadata for seeds
│
├── snapshots/                    # (Not used)
│   └── .gitkeep
│
├── models/
│   ├── staging/                 # Raw → staged
│   │   └── jaffle_shop/
│   │       ├── stg_*.sql        # Staging models
│   │       └── *_models.yml     # Model metadata
│   │
│   ├── intermediate/            # Jinja exploration models
│   │   └── jinja_examples/
│   │       └── *.txt            # Jinja test files
│   │
│   └── exposures/               # dbt exposure examples
│       └── mkt/
│           └── mkt_exposures.yml
│
├── macros/                       # Custom macros
│   ├── usd_to_brl.sql
│   ├── limit_days.sql
│   └── .gitkeep
│
├── analyses/                     # (Empty placeholder)
│   └── .gitkeep
│
├── tests/                        # (Empty placeholder)
│   └── .gitkeep
│
├── docs/
│   └── dbt-certification/        # Study material for dbt certification
│       ├── *.md                  # Study notes by topic
│       ├── 00 - Summary.md       # Summary of key topics
│       ├── images/               # Visual references for study material
│       │   └── images_*/*        # Organized by section/topic
│       └── docs/                 # (Optional: internal doc pages)
```

---

## ✨ Key Features

- **Staging Models**: All raw data from seeds are staged under `models/staging/jaffle_shop`, following the `stg_*` naming convention.
- **Custom Macros**: Includes utilities such as currency conversion and date limitation.
- **Intermediate Layer**: Includes Jinja model explorations and non-standard formats to practice Jinja logic.
- **Exposures**: Tracks dependencies between models and downstream use cases.
- **Certification Notes**: Detailed, topic-by-topic markdowns and images to prepare for the dbt Developer Certification.
- **Seeded Raw Data**: CSV files provide a controlled input layer.
- **Project Modularity**: Separation by layer and domain, facilitating a real-world modular dbt design.

---

## 📚 Certification Content

This project includes guided markdowns and images covering topics such as:

- dbt fundamentals
- Refactoring SQL for modularity
- Jinja, Macros, and Packages
- Advanced materializations
- Testing strategies
- Exposures and documentation
- dbt Mesh concepts
- Deployment strategies
- Certification practice videos

Find all in [`/docs/dbt-certification`](./docs/dbt-certification).

---

## 🧠 Inspiration

This project is based on the open-source [`jaffle_shop`](https://github.com/dbt-labs/jaffle_shop) starter dbt project and extended with a focus on:

- Realistic data modeling flow
- Modular dbt project structure
- dbt Developer Certification preparation

---

Feel free to fork and adapt for your own learning journey!
