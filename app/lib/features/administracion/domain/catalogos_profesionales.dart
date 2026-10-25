/// Referencias profesionales; no conceden roles ni permisos en la aplicación.
class ColegioProfesional {
  final String codigo, nombre;
  final bool activo;
  const ColegioProfesional(this.codigo, this.nombre, this.activo);
}

/// Distingue una especialidad de un área formativa de Tecnología Médica.
/// Los ámbitos clínicos del catálogo son orientativos, no áreas de acceso.
class EspecialidadProfesional {
  final String codigo, colegioCodigo, nombre, tipo;
  final bool activo;
  const EspecialidadProfesional(
    this.codigo,
    this.colegioCodigo,
    this.nombre,
    this.tipo,
    this.activo,
  );
}

class CatalogosProfesionales {
  final List<ColegioProfesional> colegios;
  final List<EspecialidadProfesional> especialidades;
  const CatalogosProfesionales(this.colegios, this.especialidades);
}
