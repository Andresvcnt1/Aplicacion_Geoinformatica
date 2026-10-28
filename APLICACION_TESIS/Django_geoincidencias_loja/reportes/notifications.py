import logging
import os
from pathlib import Path
from threading import Lock

from django.utils import timezone

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_initialization_attempted = False
_firebase_initialization_lock = Lock()

_INVALID_TOKEN_CODES = {
    'UNREGISTERED',
    'INVALID_ARGUMENT',
    'SENDER_ID_MISMATCH',
    'REGISTRATION-TOKEN-NOT-REGISTERED',
    'INVALID-REGISTRATION-TOKEN',
    'MISMATCHED-CREDENTIAL',
    'INVALID-ARGUMENT',
}
_INVALID_TOKEN_ERRORS = {
    'InvalidArgumentError',
    'SenderIdMismatchError',
    'UnregisteredError',
}


def _get_firebase_app():
    global _firebase_app, _firebase_initialization_attempted

    if _firebase_initialization_attempted:
        return _firebase_app

    with _firebase_initialization_lock:
        if _firebase_initialization_attempted:
            return _firebase_app

        credentials_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        if not credentials_path:
            logger.warning(
                'FIREBASE_CREDENTIALS_PATH no está configurada; '
                'las notificaciones push permanecerán deshabilitadas.'
            )
            _firebase_initialization_attempted = True
            return None

        if not Path(credentials_path).is_file():
            logger.warning(
                'No existe el archivo de credenciales FCM configurado; '
                'las notificaciones push permanecerán deshabilitadas.'
            )
            _firebase_initialization_attempted = True
            return None

        try:
            import firebase_admin
            from firebase_admin import credentials

            try:
                _firebase_app = firebase_admin.get_app()
            except ValueError:
                credential = credentials.Certificate(credentials_path)
                _firebase_app = firebase_admin.initialize_app(credential)
        except Exception:
            logger.warning(
                'No se pudo inicializar Firebase Admin; '
                'las notificaciones push permanecerán deshabilitadas.',
                exc_info=True,
            )
            _firebase_app = None
        finally:
            _firebase_initialization_attempted = True

    return _firebase_app


def _is_invalid_token_error(error):
    code = str(getattr(error, 'code', '')).rsplit('/', 1)[-1].upper()
    return (
        code in _INVALID_TOKEN_CODES
        or error.__class__.__name__ in _INVALID_TOKEN_ERRORS
    )


def enviar_push_cambio_estado(incidencia, nuevo_estado):
    if incidencia.usuario is None:
        return

    dispositivos = incidencia.usuario.dispositivos_push.filter(activo=True)
    if not dispositivos.exists():
        return

    app = _get_firebase_app()
    if app is None:
        return

    from firebase_admin import messaging

    etiqueta_estado = dict(incidencia.Estado.choices)[nuevo_estado]
    mensaje = (
        f'Tu reporte #{incidencia.id} cambió a {etiqueta_estado}'
    )

    for dispositivo in dispositivos.iterator():
        try:
            notificacion = messaging.Message(
                notification=messaging.Notification(
                    title='GeoIncidencias Loja',
                    body=mensaje,
                ),
                data={
                    'incidencia_id': str(incidencia.id),
                    'estado': nuevo_estado,
                    'tipo': 'cambio_estado',
                },
                android=messaging.AndroidConfig(priority='high'),
                token=dispositivo.token,
            )
            messaging.send(notificacion, app=app)
        except Exception as error:
            if _is_invalid_token_error(error):
                try:
                    dispositivo.activo = False
                    dispositivo.fecha_actualizacion = timezone.now()
                    dispositivo.save(
                        update_fields=['activo', 'fecha_actualizacion']
                    )
                except Exception:
                    logger.error(
                        'No se pudo desactivar el dispositivo push %s '
                        'tras un error de token inválido.',
                        dispositivo.pk,
                        exc_info=True,
                    )
            logger.error(
                'Falló el envío de notificación FCM al dispositivo %s (código: %s).',
                dispositivo.pk,
                getattr(error, 'code', error.__class__.__name__),
                exc_info=True,
            )
