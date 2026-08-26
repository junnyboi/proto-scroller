class_name FinaleEligibilitySnapshot
extends RefCounted

const DOSSIER_REQUIREMENT: int = 20
const EVIDENCE_REQUIREMENT: int = 5

var dossier_count: int
var evidence_count: int
var continuity_generation: int
var disentangle_eligible: bool


static func from_store(store: CampaignProgressStore) -> FinaleEligibilitySnapshot:
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.new()
	if store == null:
		return snapshot
	snapshot.dossier_count = store.dossier_count()
	snapshot.evidence_count = store.evidence_count()
	snapshot.continuity_generation = store.continuity_generation()
	snapshot.disentangle_eligible = (
		snapshot.dossier_count >= DOSSIER_REQUIREMENT
		and snapshot.evidence_count >= EVIDENCE_REQUIREMENT
	)
	return snapshot


func as_dictionary() -> Dictionary:
	return {
		"dossier_count": dossier_count,
		"dossier_requirement": DOSSIER_REQUIREMENT,
		"evidence_count": evidence_count,
		"evidence_requirement": EVIDENCE_REQUIREMENT,
		"continuity_generation": continuity_generation,
		"disentangle_eligible": disentangle_eligible,
	}
