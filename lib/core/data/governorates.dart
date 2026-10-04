/// `App\Enums\Governorate` in the backend — the values `POST
/// /customer/auth/register/email` accepts. Labels are English source strings;
/// Arabic names are in `ar_extra.dart`.
const governorates = <(String, String)>[
  ('cairo', 'Cairo'),
  ('giza', 'Giza'),
  ('alexandria', 'Alexandria'),
  ('qaliubia', 'Qaliubia'),
  ('dakahlia', 'Dakahlia'),
  ('sharkia', 'Sharkia'),
  ('gharbia', 'Gharbia'),
  ('menofia', 'Menofia'),
  ('beheira', 'Beheira'),
  ('kafr_el_sheikh', 'Kafr El Sheikh'),
  ('damietta', 'Damietta'),
  ('port_said', 'Port Said'),
  ('ismailia', 'Ismailia'),
  ('suez', 'Suez'),
  ('fayoum', 'Fayoum'),
  ('beni_suef', 'Beni Suef'),
  ('minya', 'Minya'),
  ('asyut', 'Asyut'),
  ('sohag', 'Sohag'),
  ('qena', 'Qena'),
  ('luxor', 'Luxor'),
  ('aswan', 'Aswan'),
  ('red_sea', 'Red Sea'),
  ('new_valley', 'New Valley'),
  ('matrouh', 'Matrouh'),
  ('north_sinai', 'North Sinai'),
  ('south_sinai', 'South Sinai'),
];

/// Inspection and handover happen at IGI in Cairo for now (prototype note).
bool isInCoverage(String governorate) => governorate == 'cairo' || governorate == 'giza';
