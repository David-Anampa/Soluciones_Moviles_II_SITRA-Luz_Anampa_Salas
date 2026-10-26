/// Unifica los cargos que pueden recibir el permiso adicional de gestionar kits.
/// No crea roles nuevos; el servidor vuelve a validar cargo, rol y áreas.
bool cargoPermiteKits(String cargo) {
  var valor = cargo.trim().toLowerCase();
  const tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
  for (final entrada in tildes.entries) {
    valor = valor.replaceAll(entrada.key, entrada.value);
  }
  return const {
    'tecnica',
    'tecnico',
    'tecnica de enfermeria',
    'tecnico de enfermeria',
    'enfermera',
    'enfermero',
    'licenciada en enfermeria',
    'licenciado en enfermeria',
  }.contains(valor);
}
