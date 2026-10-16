/// Known Napas BIN codes for the banks this app targets (see SPEC.md).
/// "Khác" (other) lets the user type a BIN manually for banks not listed.
class BankDirectoryEntry {
  final String name;
  final String bin;

  const BankDirectoryEntry({required this.name, required this.bin});
}

const bankDirectory = <BankDirectoryEntry>[
  BankDirectoryEntry(name: 'MBBank', bin: '970422'),
  BankDirectoryEntry(name: 'Vietcombank', bin: '970436'),
  BankDirectoryEntry(name: 'Techcombank', bin: '970407'),
];
