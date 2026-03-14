/*
* Proyecto1.asm
*
* Creado: 25/02/2026
* Autor : Giancarlo Custodio Lara
* Descripción: Reloj digital con fecha y alarma configurable
*/
//**************************************************
// Encabezado (Definición de Registros, Variables y Constantes)

.include "M328PDEF.inc" // Include definitions specific to ATMega328P


//**************************************************
// DEFINICION DE REGISTROS 
//**************************************************
.def UNIDADES_MIN       = R18       // UNIDADES MINUTOS
.def DEC_MIN            = R19       // DECENAS MINUTOS
.def UNIDADES_HORA      = R20       // UNIDADES HORA
.def DEC_HORAS          = R21       // DECENAS HORA

.def UNIDADES_DIA       = R26       // UNIDADES DIA
.def DEC_DIA            = R27       // DECENAS DIA
.def UNIDADES_MES       = R28       // UNIDADES MES
.def DEC_MES            = R29       // DECENAS MES

.def A_UNID_MIN         = R10       // ALARMA: UNIDADES MINUTOS
.def A_DEC_MIN          = R11       // ALARMA: DECENAS MINUTOS
.def A_UNID_HOR         = R12       // ALARMA: UNIDADES HORA
.def A_DEC_HOR          = R13       // ALARMA: DECENAS HORA

.def CONTADOR_SEG       = R22       // CONTADOR SEGUNDOS INTERNO
.def ESTADO_DP          = R23       // Bit 0: Puntos, Bit 1: Bandera Alarma
.def FLAG_MULTIPLEX     = R24       // SELECTOR DE DIGITO A MOSTRAR
.equ VALOR_TIMER1       = 49911     // PRECARGA TIMER 1 (1 SEGUNDO)

.equ MAX_MODOS          = 5         // TOTAL DE MODOS DEL SISTEMA
.def MODO               = R25       // MODO ACTUAL
.def B_MODO             = R17       // LECTURA DE BOTON MODO

.cseg
.org 0x0000
    JMP SETUP

.org PCI0addr       
    JMP ISR_PCINT0                  

.org PCI1addr
    JMP ISR_PCINT1                  // Boton

.org 0x001A
    JMP ISR_TIMER1_OVF              // Contador de tiempo

.org 0x0020
    JMP ISR_TIMER0_OVF              // Multiplex

//**************************************************
// TABLAS EN MEMORIA FLASH
//**************************************************
T7S:
.db 0x3F,0x06,0x5B,0x4F,0X66,0X6D,0X7D,0X07 // DIGITOS 0-7 (Catodo Comun)
.db 0X7F,0X6F,0X77,0X7C,0X39,0X5E,0X79,0X71 // DIGITOS 8-F


//**************************************************
// CONFIGURACION INICIAL DEL MICROCONTROLADOR
//**************************************************
SETUP:
    CLR MODO
    CLR B_MODO
    
    //**************************************************
    // Configuración de la pila
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    LDI R16, 0x00
    STS UCSR0B, R16                 // Habilitar pines de PORTD
    
    //**************************************************
    // Salidas y Entradas

    // PORTD - DISPLAY 7 SEGMENTOS
    LDI R16, 0b1111_1111
    OUT DDRD, R16                   

    // PORTB - Botones y LEDs
    LDI R16, 0b0011_0000    
    OUT DDRB, R16                   // PB4: Buzzer, PB5: LED ROJO
    SBI PORTB, PB0                  // Habilitar Pull-Ups botones PB0-PB3
    SBI PORTB, PB1
    SBI PORTB, PB2
    SBI PORTB, PB3

    // PORTC - MULTIPLEX y B_MODO
    LDI R16, 0b0010_1111    
    OUT DDRC, R16                   // PC0-PC3: MULTIPLEX
    SBI PORTC, PC4                  // Pull-Up Boton Modo (PC4)

    //**************************************************
    // Inicializar Valores del Reloj

    // HORA: 00:00
    CLR UNIDADES_MIN
    CLR DEC_MIN
    CLR UNIDADES_HORA
    CLR DEC_HORAS

    // FECHA: 01/01
    LDI DEC_DIA, 0
    LDI UNIDADES_DIA, 1
    LDI DEC_MES, 0
    LDI UNIDADES_MES, 1

    // ALARMA: 00:00
    CLR A_UNID_MIN
    CLR A_DEC_MIN
    CLR A_UNID_HOR
    CLR A_DEC_HOR

    // Otros registros importantes
    CLR FLAG_MULTIPLEX
    CLR CONTADOR_SEG
    CLR ESTADO_DP

    // Interrupciones en los botones
    LDI R16, (1 << PCIE1) | (1 << PCIE0)
    STS PCICR, R16
    LDI R16, (1 << PCINT12)
    STS PCMSK1, R16
    LDI R16, (1 << PCINT0)|(1 << PCINT1)|(1 << PCINT2)|(1 << PCINT3)
    STS PCMSK0, R16

    CALL TIMER0
    CALL TIMER1

    SEI                             // Activar interrupciones globales

//**************************************************
// MAIN LOOP
//**************************************************
MAIN_LOOP:
    CPI MODO, 0
    BREQ MODO_MOSTRAR_HORA

    CPI MODO, 1
    BREQ MODO_MOSTRAR_FECHA

    CPI MODO, 2
    BREQ MODO_CONF_HORA

    CPI MODO, 3
    BREQ MODO_CONF_FECHA

    CPI MODO, 4
    BREQ MODO_CONF_ALARMA

    RJMP MAIN_LOOP

MODO_MOSTRAR_HORA:
    // LED ROJO: 0 , LED AZUL: 0
    CBI PORTC, PC5
    CBI PORTB, PB5
    RJMP MAIN_LOOP

MODO_MOSTRAR_FECHA:
    // LED ROJO: 0 , LED AZUL: 1
    SBI PORTC, PC5
    CBI PORTB, PB5
    RJMP MAIN_LOOP

MODO_CONF_HORA:
    // LED ROJO: 1 , LED AZUL: 0
    CBI PORTC, PC5
    SBI PORTB, PB5

    SBIS PINB, PB3
    RCALL SUMAR_MINUTOS

    SBIS PINB, PB0
    RCALL RESTAR_MINUTOS

    SBIS PINB, PB1
    RCALL SUMAR_HORAS

    SBIS PINB, PB2
    RCALL RESTAR_HORAS

    RJMP MAIN_LOOP

MODO_CONF_FECHA:
    // LED ROJO: 1 , LED AZUL: 1
    SBI PORTC, PC5
    SBI PORTB, PB5

    SBIS PINB, PB3 
    RCALL SUMAR_MESES

    SBIS PINB, PB0 
    RCALL RESTAR_MESES

    SBIS PINB, PB1 
    RCALL SUMAR_DIAS

    SBIS PINB, PB2 
    RCALL RESTAR_DIAS

    RJMP MAIN_LOOP

MODO_CONF_ALARMA:
    // LED ROJO: "PARPADEO"
    CBI PORTC, PC5
    SBRC ESTADO_DP, 0
    SBI PORTB, PB5
    SBRS ESTADO_DP, 0
    CBI PORTB, PB5
    
    SBIS PINB, PB3 
    RCALL ALARMA_SUMAR_MIN

    SBIS PINB, PB0 
    RCALL ALARMA_RESTAR_MIN

    SBIS PINB, PB1 
    RCALL ALARMA_SUMAR_HORAS

    SBIS PINB, PB2 
    RCALL ALARMA_RESTAR_HORAS

    RJMP MAIN_LOOP


// RUTINAS
//**************************************************

// APAGAR ALARMA CON CUALQUIER BOTON DE AJUSTE
ISR_PCINT0:
    PUSH R16
    IN R16, SREG
    PUSH R16
    
    ANDI ESTADO_DP, 0b1111_1101     // Limpiar Bit 1 de alarma
    CBI PORTB, PB4                  // Apagar BUZZER

    POP R16
    OUT SREG, R16
    POP R16
    RETI

// CAMBIO DE MODO AL PRESIONAR PC4
//**************************************************
ISR_PCINT1:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R30
    PUSH R31

    SBIC PINC, PC4                  // Si está presionado, salir 
    RJMP SALIR_CAMBIO_MODO

    RCALL DELAY						// Delay para evitar parpadeo
    
    SBIC PINC, PC4                  // Volver a verificar 
    RJMP SALIR_CAMBIO_MODO

    INC MODO
    CPI MODO, MAX_MODOS
    BRLO LIMPIAR_ALARMA_MODO		//Si MODO es menor que el máximo, salta a limpiar alarma
    CLR MODO

LIMPIAR_ALARMA_MODO:
    ANDI ESTADO_DP, 0b1111_1101     // Cambiar de modo apaga la alarma
    CBI PORTB, PB4

SALIR_CAMBIO_MODO:
    LDI R16, (1<<PCIF1)
    OUT PCIFR, R16                  // Limpiar bandera de interrupción por rebotes al soltar
    
    POP R31
    POP R30
    POP R16
    OUT SREG, R16
    POP R16
    RETI

// MULTIPLEXADO con TIMER 0
//**************************************************
ISR_TIMER0_OVF:
    PUSH R16
    PUSH R17
    PUSH R30              
    PUSH R31              
    IN R16, SREG
    PUSH R16
    
    LDI R16, 6                      // Recarga para frecuencia correcta
    OUT TCNT0, R16
    
    CBI PORTC, PC0                  // Apagar digitos 
    CBI PORTC, PC1
    CBI PORTC, PC2
    CBI PORTC, PC3
    
    INC FLAG_MULTIPLEX
    ANDI FLAG_MULTIPLEX, 0x03       // Mantener ciclo 0, 1, 2, 3
    
    CPI MODO, 1
    BREQ MUX_FECHA
    CPI MODO, 3
    BREQ MUX_FECHA
    CPI MODO, 4
    BREQ MUX_ALARMA

MUX_HORA:
    CPI FLAG_MULTIPLEX, 0
    BREQ D0_H

    CPI FLAG_MULTIPLEX, 1
    BREQ D1_H

    CPI FLAG_MULTIPLEX, 2
    BREQ D2_H

    SBI PORTC, PC3
    MOV R17, UNIDADES_MIN

    RJMP ENVIAR_A_PANTALLA

D0_H: 
    SBI PORTC, PC1
    MOV R17, UNIDADES_HORA
    RJMP ENVIAR_A_PANTALLA
D1_H: 
    SBI PORTC, PC0
    MOV R17, DEC_HORAS
    RJMP ENVIAR_A_PANTALLA
D2_H: 
    SBI PORTC, PC2
    MOV R17, DEC_MIN
    RJMP ENVIAR_A_PANTALLA

MUX_FECHA:
    CPI FLAG_MULTIPLEX, 0
    BREQ D0_F

    CPI FLAG_MULTIPLEX, 1
    BREQ D1_F

    CPI FLAG_MULTIPLEX, 2
    BREQ D2_F

    SBI PORTC, PC3

    MOV R17, UNIDADES_MES
    RJMP ENVIAR_A_PANTALLA
D0_F: 
    SBI PORTC, PC1
    MOV R17, UNIDADES_DIA
    RJMP ENVIAR_A_PANTALLA
D1_F: 
    SBI PORTC, PC0
    MOV R17, DEC_DIA
    RJMP ENVIAR_A_PANTALLA
D2_F: 
    SBI PORTC, PC2
    MOV R17, DEC_MES
    RJMP ENVIAR_A_PANTALLA

MUX_ALARMA:
    CPI FLAG_MULTIPLEX, 0
    BREQ D0_A

    CPI FLAG_MULTIPLEX, 1
    BREQ D1_A

    CPI FLAG_MULTIPLEX, 2
    BREQ D2_A

    SBI PORTC, PC3

    MOV R17, A_UNID_MIN
    RJMP ENVIAR_A_PANTALLA

D0_A: 
    SBI PORTC, PC1
    MOV R17, A_UNID_HOR
    RJMP ENVIAR_A_PANTALLA

D1_A: 
    SBI PORTC, PC0
    MOV R17, A_DEC_HOR
    RJMP ENVIAR_A_PANTALLA

D2_A: 
    SBI PORTC, PC2
    MOV R17, A_DEC_MIN

ENVIAR_A_PANTALLA:
    LDI ZH, HIGH(T7S<<1)
    LDI ZL, LOW(T7S<<1)
    ADD ZL, R17
    LPM R17, Z

    SBRC ESTADO_DP, 0
    ORI R17, 0x80                   // Encender puntos

    OUT PORTD, R17					;Mostrar valor en el DSIPLAY
    
    POP R16
    OUT SREG, R16

    POP R31               
    POP R30               
    POP R17
    POP R16
    RETI

// RELOJ DE TIEMPO TIMER 1
//**************************************************
ISR_TIMER1_OVF:
    PUSH R16
    IN R16, SREG
	PUSH R16

	//Se usa para evitar saltos de segundos, y que se congele el display

    PUSH R17              
    PUSH R0               
    PUSH R1               
    PUSH R30
    PUSH R31

    LDI R16, HIGH(VALOR_TIMER1)
    STS TCNT1H, R16
    LDI R16, LOW(VALOR_TIMER1)
    STS TCNT1L, R16

    // Parpadeo de Puntos
    LDI R16, 0x01
    EOR ESTADO_DP, R16				//Crea parpadeo invirtiendo bit
    
    INC CONTADOR_SEG
    CPI CONTADOR_SEG, 60			// 59 seg max

    BRLO REVISAR_SONIDO_ALARMA      // Si es menor a 60, no enciende la alarma

    CLR CONTADOR_SEG				//Reinicio 

    RCALL ACTUALIZAR_TIEMPO_COMPLETO // Calculo de tiempo

REVISAR_SONIDO_ALARMA:

    CPI CONTADOR_SEG, 0             // SOLO evalúa encender la alarma en el segundo 0
    BRNE CONTROL_BUZZER             // Si ya pasó del segundo 0, ignora la validación
    
    CP UNIDADES_MIN, A_UNID_MIN
    BRNE CONTROL_BUZZER

    CP DEC_MIN, A_DEC_MIN
    BRNE CONTROL_BUZZER

    CP UNIDADES_HORA, A_UNID_HOR
    BRNE CONTROL_BUZZER

    CP DEC_HORAS, A_DEC_HOR
    BRNE CONTROL_BUZZER
    
    ORI ESTADO_DP, 0b0000_0010      // Si todos los digitos coinciden, Activa la bandera de Alarma

CONTROL_BUZZER:
    SBRS ESTADO_DP, 1               // ¿La alarma fue encendida?
    RJMP SALIR_TIMER1               // No -> SALIR_TIMER1
    
    SBRC ESTADO_DP, 0               // Si -> Hacer que pite cada 1s con los puntos
    SBI PORTB, PB4
    SBRS ESTADO_DP, 0
    CBI PORTB, PB4

SALIR_TIMER1:
    POP R31
    POP R30
    POP R1
    POP R0
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

// CONFIGURACIÒN
//**************************************************

// FUNCION: SUMAR MINUTOS

SUMAR_MINUTOS:
    INC UNIDADES_MIN
    CPI UNIDADES_MIN, 10
    BRNE FIN_SUMAR_MIN
    CLR UNIDADES_MIN

    INC DEC_MIN
    CPI DEC_MIN, 6
    BRNE FIN_SUMAR_MIN
    CLR DEC_MIN

FIN_SUMAR_MIN:
    RCALL ESPERAR_SOLTAR_PB3		//evitar rebotes
    RET

// FUNCION: RESTAR MINUTOS

RESTAR_MINUTOS:
    DEC UNIDADES_MIN
    CPI UNIDADES_MIN, 255           // Detectar Underflow (pasó de 0 a 255)
    BRNE FIN_RESTAR_MIN
    LDI UNIDADES_MIN, 9

    DEC DEC_MIN
    CPI DEC_MIN, 255
    BRNE FIN_RESTAR_MIN
    LDI DEC_MIN, 5

FIN_RESTAR_MIN:
    RCALL ESPERAR_SOLTAR_PB0
    RET

// FUNCION: SUMAR HORAS

SUMAR_HORAS:
    INC UNIDADES_HORA
    CPI UNIDADES_HORA, 10
    BRNE VERIFICAR_LIMITE_24H_SUM
    CLR UNIDADES_HORA
    INC DEC_HORAS

VERIFICAR_LIMITE_24H_SUM:
    CPI DEC_HORAS, 2
    BRNE FIN_SUMAR_HORAS
    CPI UNIDADES_HORA, 4
    BRNE FIN_SUMAR_HORAS
    CLR UNIDADES_HORA
    CLR DEC_HORAS

FIN_SUMAR_HORAS:
    RCALL ESPERAR_SOLTAR_PB1
    RET

// FUNCION: RESTAR HORAS

RESTAR_HORAS:
    DEC UNIDADES_HORA
    CPI UNIDADES_HORA, 255
    BRNE VERIFICAR_LIMITE_24H_RES
    LDI UNIDADES_HORA, 9
    DEC DEC_HORAS

VERIFICAR_LIMITE_24H_RES:
    CPI DEC_HORAS, 255              // Si las decenas bajan de 0
    BRNE FIN_RESTAR_HORAS
    LDI DEC_HORAS, 2                // Volver a las 23:00
    LDI UNIDADES_HORA, 3

FIN_RESTAR_HORAS:
    RCALL ESPERAR_SOLTAR_PB2
    RET

// FUNCION: SUMAR DIAS

SUMAR_DIAS:
    INC UNIDADES_DIA
    CPI UNIDADES_DIA, 10
    BRNE COMPROBAR_MAX_DIAS_SUM
    CLR UNIDADES_DIA
    INC DEC_DIA

COMPROBAR_MAX_DIAS_SUM:
    RCALL OBTENER_DIA_ACTUAL		//Verifica el max de dias segun el mes
    RCALL OBTENER_MAXIMO_MES  
    CP R16, R17
    BRSH FIN_SUMAR_DIAS				//Branch if Same or Higher        
    LDI UNIDADES_DIA, 1             // Si se pasa, reiniciar al dia 1
    CLR DEC_DIA

FIN_SUMAR_DIAS:
    RCALL ESPERAR_SOLTAR_PB1
    RET

// FUNCION: RESTAR DIAS

RESTAR_DIAS:
    DEC UNIDADES_DIA
    CPI UNIDADES_DIA, 255
    BRNE COMPROBAR_CERO_DIAS
    LDI UNIDADES_DIA, 9
    DEC DEC_DIA

	//Underflow con el max de dias del mes
COMPROBAR_CERO_DIAS:
    RCALL OBTENER_DIA_ACTUAL   
    CPI R17, 0                      // Si bajó al día 0
    BRNE FIN_RESTAR_DIAS
    RCALL OBTENER_MAXIMO_MES		
    CLR R17


DIVISION_RESTA_DIA:
    CPI R16, 10              
    BRLO ASIGNAR_RESTA_DIA			//Si es menor de 10, no se separa
    SUBI R16, 10
    INC R17
    RJMP DIVISION_RESTA_DIA

ASIGNAR_RESTA_DIA:
    MOV UNIDADES_DIA, R16			//Guarda unidades de dia
    MOV DEC_DIA, R17				//Guarda decenas de dia

FIN_RESTAR_DIAS:
    RCALL ESPERAR_SOLTAR_PB2
    RET

// FUNCION: SUMAR MESES

SUMAR_MESES:
    INC UNIDADES_MES
    CPI UNIDADES_MES, 10
    BRNE COMPROBAR_LIMITE_12_SUM
    CLR UNIDADES_MES
    INC DEC_MES

	//Regresa a enero si se le suma un mes a diciembre
COMPROBAR_LIMITE_12_SUM:
    CPI DEC_MES, 1
    BRNE FIN_SUMAR_MESES
    CPI UNIDADES_MES, 3

    BRNE FIN_SUMAR_MESES
    CLR DEC_MES
    LDI UNIDADES_MES, 1

FIN_SUMAR_MESES:
    RCALL ESPERAR_SOLTAR_PB3
    RET

// FUNCION: RESTAR MESES

RESTAR_MESES:
    DEC UNIDADES_MES
    CPI UNIDADES_MES, 255

    BRNE COMPROBAR_LIMITE_12_RES

    LDI UNIDADES_MES, 9
    DEC DEC_MES

	//Si se le resta un mes a enero, regresa a diciembre
COMPROBAR_LIMITE_12_RES:
    CPI DEC_MES, 0
    BRNE FIN_RESTAR_MESES

    CPI UNIDADES_MES, 0

    BRNE FIN_RESTAR_MESES

    LDI DEC_MES, 1                 
    LDI UNIDADES_MES, 2

FIN_RESTAR_MESES:
    RCALL ESPERAR_SOLTAR_PB0
    RET

// FUNCIONES DE AJUSTE: ALARMA

ALARMA_SUMAR_MIN:
	;Unidades
    INC A_UNID_MIN
    MOV R16, A_UNID_MIN
    CPI R16, 10

    BRNE FIN_ALARMA_SUMAR_MIN
    CLR A_UNID_MIN

	;Decenas
    INC A_DEC_MIN
    MOV R16, A_DEC_MIN
    CPI R16, 6

    BRNE FIN_ALARMA_SUMAR_MIN
    CLR A_DEC_MIN

FIN_ALARMA_SUMAR_MIN:
    RCALL ESPERAR_SOLTAR_PB3
    RET

ALARMA_RESTAR_MIN:
    ;Unidades
	DEC A_UNID_MIN
    MOV R16, A_UNID_MIN
    CPI R16, 255

    BRNE FIN_ALARMA_RESTAR_MIN

    LDI R16, 9
    MOV A_UNID_MIN, R16

	;Decenas
    DEC A_DEC_MIN
    MOV R16, A_DEC_MIN
    CPI R16, 255

    BRNE FIN_ALARMA_RESTAR_MIN

    LDI R16, 5
    MOV A_DEC_MIN, R16

FIN_ALARMA_RESTAR_MIN:
    RCALL ESPERAR_SOLTAR_PB0
    RET

ALARMA_SUMAR_HORAS:
    INC A_UNID_HOR
    MOV R16, A_UNID_HOR
    CPI R16, 10

    BRNE VERIFICAR_24H_ALARMA

    CLR A_UNID_HOR
    INC A_DEC_HOR

VERIFICAR_24H_ALARMA:
    MOV R16, A_DEC_HOR
    CPI R16, 2
    BRNE FIN_ALARMA_SUMAR_HORAS
    MOV R16, A_UNID_HOR

    CPI R16, 4
    BRNE FIN_ALARMA_SUMAR_HORAS

    CLR A_UNID_HOR
    CLR A_DEC_HOR

FIN_ALARMA_SUMAR_HORAS:
    RCALL ESPERAR_SOLTAR_PB1
    RET

ALARMA_RESTAR_HORAS:
	;Unidades
    DEC A_UNID_HOR
    MOV R16, A_UNID_HOR
    CPI R16, 255

    BRNE VERIFICAR_24H_RES_ALARMA
    LDI R16, 9

	;Decenas
    MOV A_UNID_HOR, R16
    DEC A_DEC_HOR

VERIFICAR_24H_RES_ALARMA:
    MOV R16, A_DEC_HOR
    CPI R16, 255

    BRNE FIN_ALARMA_RESTAR_HORAS
    LDI R16, 2

    MOV A_DEC_HOR, R16
    LDI R16, 3				;Pone en 23:00 
    MOV A_UNID_HOR, R16

FIN_ALARMA_RESTAR_HORAS:
    RCALL ESPERAR_SOLTAR_PB2
    RET


// AVANCE DE TIEMPO - Dia completo
//**************************************************
ACTUALIZAR_TIEMPO_COMPLETO:
    INC UNIDADES_MIN
    CPI UNIDADES_MIN, 10
    BRLO FIN_ACTUALIZAR_TIEMPO

    CLR UNIDADES_MIN

    INC DEC_MIN
    CPI DEC_MIN, 6
    BRLO FIN_ACTUALIZAR_TIEMPO

    CLR DEC_MIN
    
    INC UNIDADES_HORA
    CPI UNIDADES_HORA, 10
    BRNE VERIFICAR_CAMBIO_DIA

    CLR UNIDADES_HORA
    INC DEC_HORAS

//Set horas a 00 si llega a las 24
VERIFICAR_CAMBIO_DIA:
    CPI DEC_HORAS, 2
    BRNE FIN_ACTUALIZAR_TIEMPO
    CPI UNIDADES_HORA, 4

    BRNE FIN_ACTUALIZAR_TIEMPO

    CLR UNIDADES_HORA
    CLR DEC_HORAS
    
    //**************************************************
    // Lógica de Días y Meses 

    INC UNIDADES_DIA
    CPI UNIDADES_DIA, 10
    BRNE VERIFICAR_LIMITE_MES

    CLR UNIDADES_DIA
    INC DEC_DIA

VERIFICAR_LIMITE_MES:
    
    RCALL OBTENER_DIA_ACTUAL        // Guarda el dia en un solo registro
    PUSH R17                        
    RCALL OBTENER_MAXIMO_MES        // Guarda el mes en un solo registro
    POP R17                        
    
    INC R16                         // Máximo + 1 (Ejemplo: 31 pasa a 32)
    CP R17, R16                     // Comparamos día actual con el límite
    BRLO FIN_ACTUALIZAR_TIEMPO      // Si es menor al límite, salta a FIN_ACTUALIZAT_TIEMPO
    
    // Lògica para cambiar de mes
    LDI DEC_DIA, 0
    LDI UNIDADES_DIA, 1

    INC UNIDADES_MES
    CPI UNIDADES_MES, 10

    BRNE VERIFICAR_CAMBIO_ANIO		//año sin ñ
    CLR UNIDADES_MES
    INC DEC_MES

	//Si incrementa el dia el 31 de diciembre
VERIFICAR_CAMBIO_ANIO:
    CPI DEC_MES, 1
    BRNE FIN_ACTUALIZAR_TIEMPO

    CPI UNIDADES_MES, 3
    BRNE FIN_ACTUALIZAR_TIEMPO

    LDI DEC_MES, 0
    LDI UNIDADES_MES, 1

FIN_ACTUALIZAR_TIEMPO:
    RET

//**************************************************
// Control de dias por  mes

// Convierte los registros separados de mes a un solo valor (1 a 12)
OBTENER_NUMERO_MES:
    MOV R16, UNIDADES_MES
    CPI DEC_MES, 0
    BREQ FIN_OBTENER_NUM_MES
    
    PUSH R17
    LDI R17, 10				;Se suma 10 si es que hay decenas de mes
    ADD R16, R17
    POP R17
FIN_OBTENER_NUM_MES:
    RET

// limitar cantidad de dias por mes
OBTENER_MAXIMO_MES:
    RCALL OBTENER_NUMERO_MES        // Deja el mes actual (1-12) en R16
    CPI R16, 2                      // ¿Es Febrero?
    BREQ MES_28
    CPI R16, 4                      // ¿Es Abril?
    BREQ MES_30
    CPI R16, 6                      // ¿Es Junio?
    BREQ MES_30
    CPI R16, 9                      // ¿Es Septiembre?
    BREQ MES_30
    CPI R16, 11                     // ¿Es Noviembre?
    BREQ MES_30
MES_31:                             // Por defecto, cualquier otro mes tiene 31
    LDI R16, 31
    RET
MES_30:
    LDI R16, 30
    RET
MES_28:
    LDI R16, 28                     
    RET

// Junta UNIDADES_DIA y DEC_DIA en un solo número
OBTENER_DIA_ACTUAL:
    MOV R17, UNIDADES_DIA
    CPI DEC_DIA, 0
    BREQ SALIR_OBTENER_DIA
    CPI DEC_DIA, 1
    BREQ SUMAR_10_DIAS			//10 + n
    CPI DEC_DIA, 2
    BREQ SUMAR_20_DIAS			//20 + n

    // Dia 30 o 31
    PUSH R16
    LDI R16, 30
    ADD R17, R16                   
    POP R16
    RJMP SALIR_OBTENER_DIA

SUMAR_20_DIAS: 
    PUSH R16
    LDI R16, 20					// + 20
    ADD R17, R16
    POP R16
    RJMP SALIR_OBTENER_DIA

SUMAR_10_DIAS: 
    PUSH R16
    LDI R16, 10					// + 10
    ADD R17, R16
    POP R16

SALIR_OBTENER_DIA: 
    RET

// Esperar botones
//**************************************************
ESPERAR_SOLTAR_PB0:
    RCALL DELAY
B_PB0: 
    SBIS PINB, PB0
    RJMP B_PB0
    RCALL DELAY
    RET

ESPERAR_SOLTAR_PB1:
    RCALL DELAY
B_PB1: 
    SBIS PINB, PB1
    RJMP B_PB1
    RCALL DELAY
    RET

ESPERAR_SOLTAR_PB2:
    RCALL DELAY
B_PB2: 
    SBIS PINB, PB2
    RJMP B_PB2
    RCALL DELAY
    RET

ESPERAR_SOLTAR_PB3:
    RCALL DELAY
B_PB3: 
    SBIS PINB, PB3
    RJMP B_PB3
    RCALL DELAY
    RET

ESPERAR_SOLTAR_PC4:
    RCALL DELAY
B_PC4: 
    SBIS PINC, PC4
    RJMP B_PC4
    RCALL DELAY
    RET

//DELAYS - Antirebote

DELAY:
    LDI R30, 200                    
Delay1: 
    LDI R31, 255
Delay2: 
    DEC R31 
    BRNE Delay2
    DEC R30 
    BRNE Delay1
    RET

// CONFIGURACION DE TIMERS
//**************************************************
TIMER0:
    LDI R16, (1<<CS01)|(1<<CS00)
    OUT TCCR0B, R16
    LDI R16, 6
    OUT TCNT0, R16
    LDI R16, (1<<TOIE0)
    STS TIMSK0, R16
    RET

TIMER1:
    LDI R16, (1<<CS12)|(1<<CS10)
    STS TCCR1B, R16
    LDI R16, HIGH(VALOR_TIMER1)
    STS TCNT1H, R16
    LDI R16, LOW(VALOR_TIMER1)
    STS TCNT1L, R16
    LDI R16, (1<<TOIE1)
    STS TIMSK1, R16
    RET