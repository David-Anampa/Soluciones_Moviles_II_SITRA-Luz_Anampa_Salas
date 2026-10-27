import 'package:flutter_test/flutter_test.dart';
import 'package:sitra_luz/features/administracion/domain/usuario_borrador.dart';
import 'package:sitra_luz/features/administracion/domain/usuario_validadores.dart';

void main() {
  group('UsuarioValidadores.nombre', () {
    test('rechaza vacío y textos de un carácter', () {
      expect(UsuarioValidadores.nombre('', etiqueta: 'los nombres'), isNotNull);
      expect(
        UsuarioValidadores.nombre(' a ', etiqueta: 'los nombres'),
        isNotNull,
      );
    });
    test('acepta nombres válidos e ignora espacios externos', () {
      expect(
        UsuarioValidadores.nombre(' David ', etiqueta: 'los nombres'),
        isNull,
      );
    });
    test('rechaza más de 80 caracteres', () {
      expect(
        UsuarioValidadores.nombre('a' * 81, etiqueta: 'los nombres'),
        isNotNull,
      );
    });
  });

  group('UsuarioValidadores.nombreUsuario', () {
    test('acepta letras de ambas cajas, números y separadores permitidos', () {
      for (final v in [
        'dav',
        'david.anampa',
        'd_a-1',
        '1abc',
        'Dav',
        'JHuancune',
        'ABC',
        'WALTER',
        'ABC123',
        '123A',
      ]) {
        expect(UsuarioValidadores.nombreUsuario(v), isNull, reason: v);
      }
    });
    test('rechaza valores sin letras, espacios y longitud inválida', () {
      for (final v in [
        'Da',
        'ab',
        '123',
        '123456',
        '12_-',
        'da vid',
        '.abc',
        'a' * 33,
        '',
      ]) {
        expect(UsuarioValidadores.nombreUsuario(v), isNotNull, reason: v);
      }
    });
  });

  group('Correos', () {
    test('correo de acceso es obligatorio y con formato', () {
      expect(UsuarioValidadores.correoAcceso(''), isNotNull);
      expect(UsuarioValidadores.correoAcceso('sin-arroba'), isNotNull);
      expect(UsuarioValidadores.correoAcceso('a@b.pe'), isNull);
    });
  });

  group('UsuarioValidadores.contrasena', () {
    test('exige 8 caracteres sin exigir mezcla de letras y números', () {
      expect(UsuarioValidadores.contrasena('abc1'), isNotNull);
      expect(UsuarioValidadores.contrasena('abcdefgh'), isNull);
      expect(UsuarioValidadores.contrasena('12345678'), isNull);
      expect(UsuarioValidadores.contrasena('ABCDEFGH'), isNull);
      expect(UsuarioValidadores.contrasena('abcdefg1'), isNull);
    });
  });

  group('UsuarioValidadores.rol y cargo', () {
    test('rol es obligatorio', () {
      expect(UsuarioValidadores.rol(null), isNotNull);
      expect(UsuarioValidadores.rol('FARMACIA'), isNull);
    });
    test('cargo es opcional y limitado', () {
      expect(UsuarioValidadores.cargo(''), isNull);
      expect(UsuarioValidadores.cargo('a' * 81), isNotNull);
    });
  });

  group('UsuarioBorrador.toJson', () {
    test('limpia espacios y conserva las mayúsculas del nombre de usuario', () {
      const borrador = UsuarioBorrador(
        nombres: ' Ana ',
        apellidos: ' Pérez ',
        nombreUsuario: ' Ana.Perez ',
        cargo: ' Técnica ',
        rol: 'ENFERMERIA',
        areas: ['SOP'],
      );
      expect(borrador.toJson(), {
        'nombres': 'Ana',
        'apellidos': 'Pérez',
        'nombre_usuario': 'Ana.Perez',
        'cargo': 'Técnica',
        'rol': 'ENFERMERIA',
        'areas': ['SOP'],
        'puede_gestionar_kits': false,
        'colegio_codigo': null,
        'numero_colegiatura': null,
        'especialidad_codigo': null,
      });
    });
    test('no incluye contraseñas ni el correo de acceso', () {
      const borrador = UsuarioBorrador(
        nombres: 'A',
        apellidos: 'B',
        nombreUsuario: 'abc',
        cargo: '',
        rol: 'FARMACIA',
        areas: [],
      );
      expect(borrador.toJson().keys, isNot(contains('password')));
      expect(borrador.toJson().keys, isNot(contains('email')));
    });
  });
}
