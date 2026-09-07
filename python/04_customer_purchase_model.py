# %%
import os
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    PrecisionRecallDisplay,
    RocCurveDisplay,
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    confusion_matrix,
    f1_score,
    precision_recall_curve,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import (
    StratifiedKFold,
    cross_val_predict,
    cross_validate,
    train_test_split,
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import FunctionTransformer, StandardScaler
from sqlalchemy import URL, create_engine

# %% [markdown]
# # Customer repeat-purchase prediction
#
# This analysis predicts whether an eligible customer will make
# a valid purchase during September 2011.


# %% [markdown]
# ## Load and validate data
#
# %%
connection_url = URL.create(
    drivername="postgresql+psycopg2",
    username="postgres",
    password=os.environ["POSTGRES_PASS"],
    host="localhost",
    port=5432,
    database="shop",
)

engine = create_engine(connection_url)


# %%
query = """
SELECT *
FROM public.customer_snapshot_2011_09_01
"""

customer_snapshot = pd.read_sql_query(query, con=engine)
engine.dispose()

# %%
# Data Validation

assert customer_snapshot.shape == (3317, 11)
assert customer_snapshot["customer_id"].is_unique
assert customer_snapshot["customer_id"].notna().all()
assert not customer_snapshot.isna().any().any()
assert set(customer_snapshot["purchased_next_30_days"].unique()) == {0, 1}
assert customer_snapshot["purchased_next_30_days"].sum() == 967

print("All snapshot validation checks passed.")

# %% [markdown]
# ## EDA
# ### Inspect feature distributions

# %%
feature_columns = [
    "recency_days",
    "order_count",
    "gross_spend",
    "total_items",
    "unique_products",
    "return_order_count",
    "returned_value",
    "net_spend",
]

summary = customer_snapshot[feature_columns].describe(
    percentiles=[0.25, 0.50, 0.75, 0.95, 0.99]
).T.round(2)

print(summary.to_string())

# %% [markdown]
# ### Examine skewness

# %%
skewness = (
    customer_snapshot[feature_columns]
    .skew()
    .sort_values(ascending=False)
)

print(skewness.to_string())

# %% [markdown]
# ### check whether returns created negative net spending
# %%
negative_net_count = (customer_snapshot["net_spend"] < 0).sum()
print(f"Customers with negative net spending: {negative_net_count}")

# %% [markdown]
# ### Inspect the eight negative-net customers

# %%
negative_net_customers = (
    customer_snapshot.loc[
        customer_snapshot["net_spend"] < 0,
        [
            "customer_id",
            "gross_spend",
            "returned_value",
            "net_spend",
            "order_count",
            "return_order_count",
            "purchased_next_30_days",
        ],
    ]
    .sort_values("net_spend")
)

print(negative_net_customers.to_string(index=False))


# %% [markdown]
# ### Compare typical feature values between the outcome groups using medians

# %%
target_medians = (
    customer_snapshot
    .groupby("purchased_next_30_days")[feature_columns]
    .median()
    .T
)

target_medians.columns = ["no_purchase", "purchase"]
target_medians["difference"] = (
    target_medians["purchase"] - target_medians["no_purchase"]
)

print(target_medians.round(2).to_string())

# %% [markdown]
# ### Inspect return prevalence

# %%
return_prevalence = (
    customer_snapshot
    .assign(
        has_return=customer_snapshot["return_order_count"] > 0
    )
    .groupby("purchased_next_30_days")["has_return"]
    .agg(["count", "sum", "mean"])
)

print(return_prevalence.round(3).to_string())

# %% [markdown]
# ## Create train/test split

# %%
# Define the modelling data

model_features = [
    "recency_days",
    "order_count",
    "gross_spend",
    "total_items",
    "unique_products",
    "return_order_count",
    "returned_value",
]

target = "purchased_next_30_days"

X = customer_snapshot[model_features]
y = customer_snapshot[target]

# %%
# Create a train/test split

X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.20,
    random_state=42,
    stratify=y,
)
# %%
# Validate

print("X_train:", X_train.shape)
print("X_test: ", X_test.shape)

print("\nTraining target proportions:")
print(y_train.value_counts(normalize=True).sort_index().round(3))

print("\nTest target proportions:")
print(y_test.value_counts(normalize=True).sort_index().round(3))


# %% [markdown]
# ## Define 3 models
# ### Baseline model
#
# The majority-class baseline establishes the minimum predictive
# performance that a useful classifier should exceed.

# %%

baseline = DummyClassifier(
    strategy="most_frequent"
)



# %% [markdown]
# ### Logistic regression
# Next we’ll fit logistic regression with two preprocessing steps:

# 1. log1p reduces extreme right skew while retaining zeros.
# 2. StandardScaler puts features on comparable scales.

# Using a pipeline ensures these transformations are 
# learned from the training data only, preventing preprocessing leakage.

# %%
# Confirm that log1p is valid for every model feature
assert (X_train >= 0).all().all()


logistic_model = Pipeline(
    steps=[
        (
            "log_transform",
            FunctionTransformer(
                np.log1p,
                feature_names_out="one-to-one",
            ),
        ),
        ("standardize", StandardScaler()),
        (
            "classifier",
            LogisticRegression(
                max_iter=1_000,
                random_state=42,
            ),
        ),
    ]
)


# %% [markdown] 
# ### Random forest

# A random forest can model nonlinear relationships and interactions. 
# It does not require standardization or log transformation because
# tree splits depend on feature ordering rather than measurement scale.

# %%

random_forest = RandomForestClassifier(
    n_estimators=500,
    min_samples_leaf=5,
    random_state=42,
    n_jobs=-1,
)



# %% [markdown]
# ## Cross-Validation

# %%

models = {
    "baseline": baseline,
    "logistic_regression": logistic_model,
    "random_forest": random_forest,
}

scoring = {
    "balanced_accuracy": "balanced_accuracy",
    "f1": "f1",
    "roc_auc": "roc_auc",
    "average_precision": "average_precision",
}

cross_validation = StratifiedKFold(
    n_splits=5,
    shuffle=True,
    random_state=42,
)

cv_rows = []

for model_name, model in models.items():
    scores = cross_validate(
        model,
        X_train,
        y_train,
        cv=cross_validation,
        scoring=scoring,
        n_jobs=1,
    )

    row = {"model": model_name}

    for metric in scoring:
        row[f"{metric}_mean"] = scores[f"test_{metric}"].mean()
        row[f"{metric}_sd"] = scores[f"test_{metric}"].std()

    cv_rows.append(row)

cv_results = (
    pd.DataFrame(cv_rows)
    .set_index("model")
)

print(cv_results.round(3).to_string())

# %% [markdown]
# ## Select logistic regression

# Logistic regression achieved the strongest mean cross-validation
# performance across balanced accuracy, F1, ROC AUC, and average
# precision. It is selected before inspecting the test results.


# %% [markdown]
# ## Select a classification threshold

# The default threshold of 0.5 missed many purchasers. Since we have 
# no specific business cost function, maximizing F1 provides a 
# reasonable neutral compromise between precision and recall.

# Generate out-of-fold probabilities using only the training data:
# %%


oof_probabilities = cross_val_predict(
    logistic_model,
    X_train,
    y_train,
    cv=cross_validation,
    method="predict_proba",
    n_jobs=1,
)[:, 1]

precision_values, recall_values, thresholds = precision_recall_curve(
    y_train,
    oof_probabilities,
)

f1_values = (
    2
    * precision_values[:-1]
    * recall_values[:-1]
    / (
        precision_values[:-1]
        + recall_values[:-1]
        + 1e-12
    )
)

best_index = np.argmax(f1_values)
best_threshold = thresholds[best_index]

print(f"Selected threshold: {best_threshold:.3f}")
print(f"Training OOF precision: {precision_values[best_index]:.3f}")
print(f"Training OOF recall:    {recall_values[best_index]:.3f}")
print(f"Training OOF F1:        {f1_values[best_index]:.3f}")


# %% [markdown]
# ## Fit models on all training data

# %%
baseline.fit(X_train, y_train)
logistic_model.fit(X_train, y_train)
random_forest.fit(X_train, y_train)

# %%
# Logistic regression: Inspect the coefficients
logistic_coefficients = pd.DataFrame(
    {
        "feature": model_features,
        "coefficient": (
            logistic_model
            .named_steps["classifier"]
            .coef_[0]
        ),
    }
)

logistic_coefficients["odds_ratio"] = np.exp(
    logistic_coefficients["coefficient"]
)

logistic_coefficients = logistic_coefficients.sort_values(
    "coefficient",
    ascending=False,
)

print(
    logistic_coefficients
    .round(3)
    .to_string(index=False)
)

# %%
# Check predictor correlations
spearman_correlations = X_train.corr(method="spearman")

print(
    spearman_correlations
    .round(2)
    .to_string()
)


# %% [markdown]
# ## Evaluate on X_test.

# %%
# a helper function to calculate metrics 
def calculate_metrics(y_true, predictions, probabilities):
    return {
        "accuracy": accuracy_score(y_true, predictions),
        "balanced_accuracy": balanced_accuracy_score(
            y_true, predictions
        ),
        "precision": precision_score(
            y_true, predictions, zero_division=0
        ),
        "recall": recall_score(
            y_true, predictions, zero_division=0
        ),
        "f1": f1_score(
            y_true, predictions, zero_division=0
        ),
        "roc_auc": roc_auc_score(
            y_true, probabilities
        ),
        "average_precision": average_precision_score(
            y_true, probabilities
        ),
    }


# %%
# Baseline model
baseline_predictions = baseline.predict(X_test)
baseline_probabilities = baseline.predict_proba(X_test)[:, 1]

baseline_metrics = calculate_metrics(
    y_test,
    baseline_predictions,
    baseline_probabilities,
)


# %%
# Logistic regression:

logistic_predictions = logistic_model.predict(X_test)
logistic_probabilities = logistic_model.predict_proba(X_test)[:, 1]

logistic_metrics = calculate_metrics(
    y_test,
    logistic_predictions,
    logistic_probabilities
)





# %%

forest_predictions = random_forest.predict(X_test)
forest_probabilities = random_forest.predict_proba(X_test)[:, 1]

forest_metrics = calculate_metrics(
    y_test,
    forest_predictions,
    forest_probabilities,
)


# %% [markdown]
# ## Compare all three

# %%
model_comparison = pd.DataFrame(
    {
        "baseline": baseline_metrics,
        "logistic_regression": logistic_metrics,
        "random_forest": forest_metrics,
    }
).T




print(model_comparison.round(3).to_string())

print("\nBaseline model confusion matrix:")
print(confusion_matrix(y_test, baseline_predictions))
print("\nLogistic regression confusion matrix:")
print(confusion_matrix(y_test, logistic_predictions))
print("\nRandom forest confusion matrix:")
print(confusion_matrix(y_test, forest_predictions))


# %%
# apply threshold to the existing test probabilities
threshold_predictions = (
    logistic_probabilities >= best_threshold
).astype(int)

threshold_metrics = calculate_metrics(
    y_test,
    threshold_predictions,
    logistic_probabilities,
)

threshold_comparison = pd.DataFrame(
    {
        "threshold_0.5": logistic_metrics,
        "cv_selected_threshold": threshold_metrics,
    }
).T

print(threshold_comparison.round(3).to_string())

print("\nThreshold-adjusted confusion matrix:")
print(confusion_matrix(y_test, threshold_predictions))


# %% [markdown]
# ## Inspect predictions and create plots.

# %% [markdown]
# ### Create customer-level prediction output

# This connects the abstract metrics back to actual prediction cases
# %%
test_results = customer_snapshot.loc[
    X_test.index,
    ["customer_id"] + model_features,
].copy()

test_results["actual"] = y_test
test_results["probability"] = logistic_probabilities
test_results["predicted"] = threshold_predictions

test_results["outcome"] = np.select(
    [
        (test_results["actual"] == 1)
        & (test_results["predicted"] == 1),

        (test_results["actual"] == 0)
        & (test_results["predicted"] == 0),

        (test_results["actual"] == 0)
        & (test_results["predicted"] == 1),

        (test_results["actual"] == 1)
        & (test_results["predicted"] == 0),
    ],
    [
        "true_positive",
        "true_negative",
        "false_positive",
        "false_negative",
    ],
    default="unclassified",
)
# %%
# Verify that all cases are classified
assert not (
    test_results["outcome"] == "unclassified"
).any()

# %%
# Validate the outcome counts
print(
    test_results["outcome"]
    .value_counts()
    .to_string()
)
# %%
# Inspect the ten customers with the highest predicted probabilities
print(
    test_results
    .sort_values("probability", ascending=False)
    .head(10)[
        [
            "customer_id",
            "probability",
            "actual",
            "predicted",
            "recency_days",
            "order_count",
            "gross_spend",
        ]
    ]
    .round(3)
    .to_string(index=False)
)
# %% [markdown]
# ### Create evaluation plots

# Add ROC and precision–recall curves

# %%

probability_sets = {
    "Baseline": baseline_probabilities,
    "Logistic regression": logistic_probabilities,
    "Random forest": forest_probabilities,
}

fig, axes = plt.subplots(
    nrows=1,
    ncols=2,
    figsize=(12, 5),
)

for model_name, probabilities in probability_sets.items():
    RocCurveDisplay.from_predictions(
        y_test,
        probabilities,
        name=model_name,
        ax=axes[0],
    )

    PrecisionRecallDisplay.from_predictions(
        y_test,
        probabilities,
        name=model_name,
        ax=axes[1],
    )

axes[0].set_title("ROC curves")
axes[1].set_title("Precision–recall curves")

# Mark the test performance at the CV-selected threshold
axes[1].scatter(
    threshold_metrics["recall"],
    threshold_metrics["precision"],
    color="black",
    marker="x",
    s=80,
    label=f"Logistic threshold = {best_threshold:.3f}",
)

axes[1].legend()
fig.tight_layout()


# save figure for repository


project_root = Path(__file__).resolve().parent.parent
figure_dir = project_root / "reports" / "figures"
figure_dir.mkdir(parents=True, exist_ok=True)

fig.savefig(
    figure_dir / "model_evaluation_curves.png",
    dpi=300,
    bbox_inches="tight",
)

plt.show()
# %%
