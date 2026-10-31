import '../auth/profile_repository.dart';
import 'patient_search_models.dart';

/// PatientSearchAdmin's validation order and messages.
String? adminPatientSearchError(String text) =>
    text.isEmpty
        ? 'Please Provide Patient Name or Code'
        : text.length < 3
        ? 'Name or Code must be greater than 2 character'
        : adminPatientSearchInvalidCharacter(text)
        ? "Name or Code must not contain '.,-' character"
        : null;

bool adminPatientSearchInvalidCharacter(String text) =>
    text.contains('.') || text.contains(',') || text.contains('-');

bool adminPatientMayCall(AccountProfile profile, PatientSearchRow patient) =>
    !profile.isDoctor &&
    profile.value('all_access_flag') == '1' &&
    patient.value('pat_cell').isNotEmpty;

Uri adminPatientPhoneUri(PatientSearchRow patient) =>
    Uri(scheme: 'tel', path: patient.value('pat_cell'));

String adminPatientSearchScope(AccountProfile profile) => [
  profile.value('usr_id'),
  profile.value('usr_name'),
  profile.value('all_access_flag'),
  profile.value('presc_active'),
].join('|');
