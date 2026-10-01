# ============================================
# CANCER TYPE CLASSIFICATION FROM RNA-SEQ DATA
# Author: Simon Duramps
# ============================================

library(tidyverse)
library(tidymodels)
library(ranger)

# --- 1. IMPORT DATA AND LABELS ---

cancer_data <- read_csv("your_computer_path_here/data.csv")
# You can find that on READ.ME ## Resouce
labels_test <- read_csv("your_computer_path_here/labels.csv")

# example for me (windows) "C:/Users/duram/Desktop/Documents_R/Clas_cancers_per_genetic-expres/data.csv"

# --- 2. NOW, JOIN LABELS WITH DATA ---

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

# --- 7. TRAINING & EVALUATION --------------

rf_fit <- rf_workflow %>%
  fit(data = train_data)

predictions <- rf_fit %>%
  predict(test_data) %>%
  bind_cols(test_data %>% select(Class))

# --- 8. PERFORMANCE METRICS ---------------

conf_mat(predictions, truth = Class, estimate = .pred_class)

accuracy(predictions, truth = Class, estimate = .pred_class)

# --- 9. VARIABLE IMPORTANCE (Vip don't work in my version TxT miss u) ----

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

# Prediction with an external patient (took in data.csv)  ~20531 genes if I remember correctly


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