# ============================================
# CANCER TYPE CLASSIFICATION FROM RNA-SEQ DATA
# Author: Simon Duramps
# Version: with 5-fold cross-validation
# ============================================

library(tidyverse)
library(tidymodels)
library(ranger)

dossier_sortie <- "Your_computer_path_where_you_want_new-file/version_amelioree"

if (!dir.exists(dossier_sortie)) {
  dir.create(dossier_sortie) # I create for you file
}

# --- 1. IMPORT THE TWO FILES ---

cancer_data <- read_csv("your_path/data.csv")
# Remember, data on README on resource Kaggle
labels_test <- read_csv("your_computer_path/labels.csv")

#Example for me (windows) "C:/Users/duram/Desktop/Documents_R/Clas_cancers_per_genetic-expres"

# --- 2. JOIN LABELS WITH DATA ---

cancer_data <- cancer_data %>%
  select(-`...1`) %>%
  mutate(Class = labels_test$Class) %>%
  mutate(Class = as.factor(Class))

# --- 3. QUICK EXPLORATION ---------------------

glimpse(cancer_data)

cancer_data %>%
  count(Class) %>%
  ggplot(aes(x = Class, y = n, fill = Class)) +
  geom_col() +
  labs(title = "Distribution of cancer types", x = "Type", y = "Number of patients") +
  theme_minimal()

ggsave(file.path(dossier_sortie, "distribution_cancers.png"), width = 8, height = 5)

# --- 4. DATA PREPARATION ----------------

cancer_data <- cancer_data %>%
  mutate(Class = as.factor(Class))

set.seed(123)
data_split <- initial_split(cancer_data, prop = 0.75, strata = Class)

train_data <- training(data_split)
test_data  <- testing(data_split)

# --- 5. PREPROCESSING RECIPE ---------------

cancer_recipe <- recipe(Class ~ ., data = train_data) %>%
  step_zv(all_predictors()) %>%
  step_normalize(all_predictors())

# --- 6. MODELING (RANDOM FOREST) -----------

rf_spec <- rand_forest(trees = 500) %>%
  set_engine("ranger", importance = "impurity") %>%
  set_mode("classification")

rf_workflow <- workflow() %>%
  add_recipe(cancer_recipe) %>%
  add_model(rf_spec)

# --- 7. CROSS-VALIDATION 5-FOLD ----------------

set.seed(123)
folds <- vfold_cv(train_data, v = 5, strata = Class)

rf_cv <- rf_workflow %>%
  fit_resamples(
    resamples = folds,
    metrics = metric_set(accuracy, roc_auc),
    control = control_resamples(save_pred = TRUE)
  )

cv_metrics <- collect_metrics(rf_cv)
print(cv_metrics)

write_csv(cv_metrics, file.path(dossier_sortie, "cv_results.csv"))

# --- 8. FINAL TRAINING ON THE FULL TRAIN SET ---

rf_fit <- rf_workflow %>%
  fit(data = train_data)

# --- 9. EVALUATION ON THE TEST SET -------------

predictions <- rf_fit %>%
  predict(test_data) %>%
  bind_cols(test_data %>% select(Class))

conf_mat(predictions, truth = Class, estimate = .pred_class)

accuracy(predictions, truth = Class, estimate = .pred_class)

# --- 10. VARIABLE IMPORTANCE --------------

importance <- rf_fit %>%
  extract_fit_parsnip() %>%
  pluck("fit", "variable.importance")

top20 <- sort(importance, decreasing = TRUE)[1:20]

tibble(gene = names(top20), importance = top20) %>%
  ggplot(aes(x = reorder(gene, importance), y = importance)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(title = "Top 20 most predictive genes",
       x = "Gene", y = "Importance") +
  theme_minimal()

ggsave(file.path(dossier_sortie, "top20_genes.png"), width = 8, height = 6)


# --- 12. PREDICTION OF A NEW PATIENT -------

dossier_sortie <- "C:/Users/duram/Desktop/Documents_R/Clas_cancers_per_genetic-expres"

chemin <- file.path(dossier_sortie, "nouveau_patient.csv")

nouveau_patient <- read_csv(chemin) %>%
  select(-any_of("...1"))

ordre_genes <- train_data %>% select(-Class) %>% names()
nouveau_patient <- nouveau_patient %>% select(all_of(ordre_genes))

prediction <- predict(rf_fit, new_data = nouveau_patient)
probas <- predict(rf_fit, new_data = nouveau_patient, type = "prob")

cat("\n--- RESULT ---\n")
cat("Predicted cancer:", as.character(prediction$.pred_class), "\n\n")
cat("Probabilities per class:\n")
print(probas)