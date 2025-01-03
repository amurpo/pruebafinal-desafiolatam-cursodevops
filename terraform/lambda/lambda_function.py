import os
import json
import logging
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns = boto3.client('sns')

def get_alarm_severity(alarm_name):
    """
    Determina la severidad de la alarma basada en su nombre
    """
    if "Status-Check-Failed" in alarm_name:
        return "CRÍTICO"
    elif "CPU-Utilization" in alarm_name:
        return "ALTO"
    elif "Network-In" in alarm_name:
        return "MEDIO"
    return "BAJO"

def format_alarm_message(alarm_data):
   try:
       severity = get_alarm_severity(alarm_data['AlarmName'])
       timestamp = datetime.strptime(alarm_data['StateChangeTime'], '%Y-%m-%dT%H:%M:%S.%f%z')
       formatted_time = timestamp.strftime('%Y-%m-%d %H:%M:%S %Z')

       message = {
           "Severidad": severity,
           "Nombre de la Alarma": alarm_data['AlarmName'],
           "Estado": alarm_data['NewStateValue'],
           "Motivo": alarm_data['NewStateReason'],
           "Fecha y Hora": formatted_time,
       }

       logger.info(f"Procesando dimensiones para alarma: {alarm_data['AlarmName']}")
       if ('Trigger' in alarm_data and 
           'Dimensions' in alarm_data['Trigger'] and 
           len(alarm_data['Trigger']['Dimensions']) > 0):
           message["Instancia EC2"] = alarm_data['Trigger']['Dimensions'][0]['value']
           logger.info(f"ID de instancia encontrado: {message['Instancia EC2']}")

       try:
           if "CPU-Utilization" in alarm_data['AlarmName']:
               message["Detalles"] = {
                   "Métrica": "Utilización de CPU",
                   "Umbral": f"{alarm_data['Trigger']['Threshold']}%",
                   "Valor Actual": alarm_data['NewStateReason']
               }
           elif "Network-In" in alarm_data['AlarmName']:
               message["Detalles"] = {
                   "Métrica": "Tráfico de Red Entrante",
                   "Umbral": f"{alarm_data['Trigger']['Threshold']} bytes",
                   "Valor Actual": alarm_data['NewStateReason']
               }
           elif "Status-Check-Failed" in alarm_data['AlarmName']:
               message["Detalles"] = {
                   "Métrica": "Status Check",
                   "Tipo": "System Status Check y Instance Status Check",
                   "Estado": "Fallido" if alarm_data['NewStateValue'] == 'ALARM' else "Recuperado"
               }
           logger.info(f"Detalles procesados para alarma tipo: {alarm_data['AlarmName']}")
       except Exception as e:
           logger.error(f"Error procesando detalles específicos: {str(e)}")
           message["Detalles"] = {"Error": "No se pudieron procesar los detalles específicos"}

       return message
   except Exception as e:
       logger.error(f"Error al formatear mensaje: {str(e)}")
       raise

def lambda_handler(event, context):
    """
    Procesa los mensajes de alarma y envía notificaciones personalizadas
    """
    logger.info("Evento recibido: %s", json.dumps(event))
    
    try:
        sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    except KeyError:
        logger.error("No se encontró la variable de entorno SNS_TOPIC_ARN")
        raise
        
    for record in event['Records']:
        try:
            # Modificación aquí para manejar el mensaje de SNS correctamente
            body = json.loads(record['body']) if isinstance(record['body'], str) else record['body']
            message_str = body.get('Message')
            if not message_str:
                logger.error("No se encontró el campo Message en el body")
                continue
                
            message = json.loads(message_str)
            logger.info("Procesando alarma: %s", message['AlarmName'])
            
            formatted_message = format_alarm_message(message)
            
            # Crear asunto personalizado según la severidad
            subject = f"[{formatted_message['Severidad']}] {message['AlarmName']} - {message['NewStateValue']}"
            
            # Enviar a SNS
            response = sns.publish(
                TopicArn=sns_topic_arn,
                Subject=subject[:100],  # SNS tiene un límite de 100 caracteres para el asunto
                Message=json.dumps(formatted_message, indent=2, ensure_ascii=False),
                MessageStructure='string'
            )
            
            logger.info("Notificación enviada: %s", response['MessageId'])
            
        except json.JSONDecodeError as e:
            logger.error("Error al decodificar mensaje: %s", str(e))
            continue
        except KeyError as e:
            logger.error("Error al procesar mensaje: Falta la clave %s", str(e))
            continue
        except Exception as e:
            logger.error("Error inesperado procesando mensaje: %s", str(e))
            continue
                
    return {
        'statusCode': 200,
        'body': json.dumps('Alarmas procesadas exitosamente')
    }

