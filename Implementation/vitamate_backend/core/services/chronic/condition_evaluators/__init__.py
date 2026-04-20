from core.services.chronic.condition_catalog_service import ConditionCatalogService
from core.services.chronic.condition_evaluators.diabetes import DiabetesEvaluator
from core.services.chronic.condition_evaluators.dyslipidemia import DyslipidemiaEvaluator
from core.services.chronic.condition_evaluators.hypertension import HypertensionEvaluator


def evaluator_for_condition(user_condition):
    slug = ConditionCatalogService.canonical_slug(user_condition.condition_type)
    if slug == "diabetes":
        return DiabetesEvaluator()
    if slug == "hypertension":
        return HypertensionEvaluator()
    if slug == "dyslipidemia":
        return DyslipidemiaEvaluator()
    raise ValueError(f"Unsupported chronic condition evaluator for slug '{slug}'.")
