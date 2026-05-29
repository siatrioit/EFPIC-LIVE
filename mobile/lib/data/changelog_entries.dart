/// In-app changelog — uzturi sinhronizētu ar [CHANGELOG.md] repozitorijā.
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.summary,
    required this.items,
  });

  final String version;
  final String date;
  final String summary;
  final List<String> items;
}

const appChangelog = <ChangelogEntry>[
  ChangelogEntry(
    version: '0.2.1',
    date: '2026-05-29',
    summary: 'Versiju izsekošana lietotnē',
    items: [
      'Ekrāns «Par programmu» ar versiju un izmaiņu žurnālu',
      'CHANGELOG.md repozitorijā',
      'Web API /health atgriež app_version no config',
    ],
  ),
  ChangelogEntry(
    version: '0.2.0',
    date: '2026-05-29',
    summary: 'FTP, imports, brīdinājumi',
    items: [
      'Īsta FTP augšupielāde ar JPG apstrādi',
      'Live: automātiska mapes uzraudzība',
      'Download: skenēt mapi, pievienot failus, importa dialogs',
      'Brīdinājumi par bateriju, internetu un pabeigtiem FTP',
    ],
  ),
  ChangelogEntry(
    version: '0.1.0',
    date: '2026-05-29',
    summary: 'Pirmā publiskā bāze',
    items: [
      'Galeriju izveide, Live/Download iestatījumi',
      'FTP preseti, Web galerijas URL',
      'PHP API skelets serverim',
    ],
  ),
];

/// Jāatbilst `pubspec.yaml` major.minor.patch daļai.
const String appVersionLabel = '0.2.1';
