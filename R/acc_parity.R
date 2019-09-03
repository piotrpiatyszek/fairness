#' @title Accuracy parity
#'
#' @description
#' This function computes the Accuracy parity metric
#'
#' @details
#' This function computes the Accuracy parity metric as described by Friedler et al., 2018.
#' Accuracy metrics are calculated by the division of correctly predicted observations (the sum
#' of all true positives and true negatives) with the number of all predictions In the returned
#' named vector, the reference group will be assigned 1, while all other groups will be assigned values
#' according to whether their accuracies are lower or higher compared to the reference group. Lower
#' accuracies will be reflected in numbers lower than 1 in the returned named vector, thus numbers
#' lower than 1 mean WORSE prediction for the subgroup.
#'
#' @param data The dataframe that contains the necessary columns.
#' @param outcome The column name of the actual outcomes.
#' @param group Sensitive group to examine.
#' @param probs The column name of the predicted probabilities (numeric between 0 - 1). If not defined, argument preds need to be defined.
#' @param preds The column name of the predicted outcome (categorical outcome). If not defined, argument probs need to be defined.
#' @param preds_levels The desired levels of the predicted outcome (categorical outcome). As these levels are commonly defined as yes/no, the function uses this as default.
#' @param cutoff Cutoff to generate predicted outcomes from predicted probabilities. Default set to 0.5.
#' @param base Base level for sensitive group comparison
#'
#' @name acc_parity
#'
#' @return
#' \item{Metric}{Accuracy parity metrics for all groups. Lower values compared to the reference group mean accuracies in the selected subgroups}
#' \item{Metric_plot}{Bar plot of Accuracy parity metric}
#' \item{Probability_plot}{Density plot of predicted probabilities per subgroup. Only plotted if probabilities are defined}
#'
#' @examples
#' df <- fairness::compas
#' acc_parity(data = df, outcome = df$score, group = df$race, base = "Caucasian")
#'
#' @export

acc_parity <- function(data, outcome, group, probs = NULL, preds = NULL,
                       preds_levels = c("no","yes"), cutoff = 0.5, base = NULL) {

  # convert types, sync levels
  group_status <- as.factor(data[,group])
  outcome_status <- as.factor(data[,outcome])
  levels(outcome_status) <- preds_levels
  if (is.null(probs)) {
    preds_status <- as.factor(data[,preds])
  } else {
    preds_status <- as.factor(as.numeric(data[,probs] > cutoff))
  }
  levels(preds_status) <- preds_levels

  # check lengths
  if ((length(outcome_status) != length(preds_status)) |
      (length(outcome_status) != length(group_status))) {
    stop("Outcomes, predictions/probabilities and group status must be of the same length")
  }

  # relevel group
  if (is.null(base)) {
    base <- levels(group_status)[1]
  }
  group_status <- relevel(group_status, base)

  # placeholder
  val <- rep(NA, length(levels(group_status)))
  names(val) <- levels(group_status)

  # compute value for base group
  cm_base <- caret::confusionMatrix(preds_status[group_status == base],
                                    outcome_status[group_status == base], mode = "everything")
  metric_base <- cm_base$overall[1]

  # compute value for other groups
  for (i in levels(group_status)) {
    cm <- caret::confusionMatrix(preds_status[group_status == i],
                                 outcome_status[group_status == i], mode = "everything")
    metric_i <- cm$overall[1]
    val[i] <- metric_i / metric_base
  }

  #conversion of metrics to df
  val_df <- as.data.frame(val)
  val_df$groupst <- rownames(val_df)
  val_df$groupst <- as.factor(val_df$groupst)
  # relevel group
  if (is.null(base)) {
    val_df$groupst <- levels(val_df$groupst)[1]
  }
  val_df$groupst <- relevel(val_df$groupst, base)

  p <- ggplot(val_df, aes(x=groupst, weight=val, fill=groupst)) +
    geom_bar(alpha=.5) +
    coord_flip() +
    theme(legend.position = "none") +
    labs(x = "", y = "Accuracy Parity")

  #plotting
  if (!is.null(probs)) {
    probs_vals <- data[,probs]
    q <- ggplot(data, aes(x=probs_vals, fill=group_status)) +
      geom_density(alpha=.5) +
      labs(x = "Predicted probabilities") +
      guides(fill = guide_legend(title = "")) +
      theme(plot.title = element_text(hjust = 0.5)) +
      xlim(0,1)
  }

  if (is.null(probs)) {
    list(Metric = val, Metric_plot = p)
  } else {
    list(Metric = val, Metric_plot = p, Probability_plot = q)
  }

}