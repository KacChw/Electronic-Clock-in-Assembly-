;------------------------------------------------------------------------
; Program zegaraelektronicznego w oknie LCD
;   Zegar wyświetla godziny, minuty i sekundy (00:00:00)
;   Ent jest obsługiwanym klawiszem (naprzemiennie start/stop stopera)
;------------------------------------------------------------------------

CZAS_HOUR EQU 20H      ; Godziny
CZAS_MIN  EQU 21H      ; Minuty
CZAS_SEC  EQU 22H      ; Sekundy
LECI      EQU 23H      ; start/stop minutnika - zmienna bitowa (0/1)
BRZECZYK  EQU P1.5     ; Brzęczyk podłączony do P1.5
DIODA     EQU P1.7     ; Dioda podłączona do P1.7
LICZNIK_50MS EQU 24H   ; Licznik przerwań co 50 ms
POP_HOUR EQU 25H       ; Poprzednia godzina

BRAMKA0 EQU 0          ; brak bramkowania timera nr 0
LINIA0  EQU 0          ; zliczanie taktów zegara
TRYB0   EQU 1          ; tryb liczenia (2 bajtowy)
STERUJ0 EQU TRYB0+4*LINIA0+8*BRAMKA0  ; słowo sterujące timera nr 0
LADUJ0  EQU 256-180    ; przeładowanie co 50 ms

    LJMP    START

    ORG    03H                ; przerwanie z wejścia zewnętrznego nr 0
    RETI                        ; pusta obsługa
    ORG    0BH                ; przerwanie z timera nr 0
    LJMP    MINUTNIK            ; skok do właściwej procedury obsługi
    ORG    13H                ; przerwanie z wejścia zewnętrznego nr 1
    RETI                        ; pusta obsługa
    ORG    1BH    
    RETI                        ; przerwanie z timera nr 1
    ; pusta obsługa
    ORG    23H                ; przerwanie z transmisji szeregowej (RS)
    RETI                        ; pusta obsługa

    ORG    100H
START:                        ; początek programu
    LCALL    LCD_INIT        ; włączenie okna LCD
    MOV    CZAS_HOUR, #0      ; ustawienie początkowych godzin
    MOV    CZAS_MIN, #0       ; ustawienie początkowych minut
    MOV    CZAS_SEC, #0      ; ustawienie początkowych sekund
    MOV    LECI, #0           ; zatrzymanie minutnika
    MOV    LICZNIK_50MS, #20  ; ustawienie licznika przerwań co 50 ms
    MOV    POP_HOUR, #0       ; ustawienie początkowej poprzedniej godziny
    LCALL    AKTUALIZUJ_LCD_MAIN
    MOV    TMOD, #STERUJ0    ; zaprogramowanie timera
    MOV    TL0, #0            ; załadowanie bajtów
    MOV    TH0, #LADUJ0       ; timera nr 0
    SETB    ET0            ; odblokowanie przerwania z timera nr 0
    SETB    EA            ; odblokowanie systemu przerwań
    SETB    TR0            ; włączenie timera nr 0
PETLA:                        ; pętla programu głównego
    LCALL    WAIT_KEY        ; czytanie klawiatury
    CJNE    A, #14, KLAWISZ_A    ; klawisz inny niż Esc - ignorowany
    XRL    LECI, #1            ; klawisz Esc – start/stop minutnika
    SJMP    PETLA            ; powrót do pętli głównej programu
KLAWISZ_A:
    CJNE    A, #15, KLAWISZ_B ; sprawdzenie czy klawisz to "Ent"
    MOV CZAS_HOUR, #0
    MOV CZAS_MIN, #0
    MOV CZAS_SEC, #0
    CLR BRZECZYK           ; Wyłącz brzęczyk (P1.5 = 0)
    LCALL    AKTUALIZUJ_LCD_MAIN
    SJMP    PETLA           ; powrót do pętli głównej programu
KLAWISZ_B:
    CJNE    A, #12, KLAWISZ_C    ; sprawdzenie czy klawisz to ">"
    MOV A, CZAS_MIN
    CJNE A, #59, INKREMENTUJ_MINUTY ; jeśli CZAS_MIN != 59, inkrementuj
    MOV CZAS_MIN, #0                    ; jeśli CZAS_MIN == 59, ustaw na 0
    SJMP    AKTUALIZUJ_LCD_MAIN
INKREMENTUJ_MINUTY:
    INC CZAS_MIN
    LCALL    AKTUALIZUJ_LCD_MAIN
    SJMP    PETLA           ; powrót do pętli głównej programu
KLAWISZ_C:
    CJNE A, #11, PETLA    ; sprawdzenie czy klawisz to "<"
    MOV A, CZAS_HOUR
    CJNE A, #13, INKREMENTUJ_GODZINY ; jeśli CZAS_HOUR != 13, inkrementuj
    MOV CZAS_HOUR, #1                   ; jeśli CZAS_HOUR == 13, ustaw na 1
    SJMP    AKTUALIZUJ_LCD_MAIN
INKREMENTUJ_GODZINY:
    INC CZAS_HOUR
    LCALL    AKTUALIZUJ_LCD_MAIN
    SJMP    PETLA           ; powrót do pętli głównej programu

AKTUALIZUJ_LCD_MAIN:
    LCALL LCD_CLR           ; Wyczyść okno LCD
    MOV A, CZAS_HOUR        ; Do aktualnych godzin
    LCALL PISZ_DEC2        ; Wypisz godziny
    MOV A, #':'
    LCALL PISZ_ZNAK
    MOV A, CZAS_MIN        ; Do aktualnych minut
    LCALL PISZ_DEC2        ; Wypisz minuty
    MOV A, #':'
    LCALL PISZ_ZNAK
    MOV A, CZAS_SEC
    LCALL PISZ_DEC2        ; Wypisz sekundy

    ; Sprawdź, czy godzina zmienia się na 12 i zmień stan diody
    MOV A, POP_HOUR
    CJNE A, CZAS_HOUR, SPRAWDZ_12   ; Jeśli godzina się zmieniła, sprawdź dalej
    SJMP KONIEC                    ; Jeśli godzina się nie zmieniła, zakończ

SPRAWDZ_12:
    MOV A, CZAS_HOUR
    CJNE A, #12, AKTUALIZUJ_POP_HOUR ; Jeśli godzina != 12, aktualizuj POP_HOUR
    CPL P1.7                         ; Jeśli godzina == 12, zmień stan diody

AKTUALIZUJ_POP_HOUR:
    MOV A, CZAS_HOUR
    MOV POP_HOUR, A                  ; Aktualizuj poprzednią godzinę
KONIEC:
    RET

;------------------------------------------------------------------------
; Procedura obsługi przerwania z timera nr 0 ()
;   Aktualizacja minutnika wykonywana co 50ms
;   Klawisz Ent naprzemiennie startuje i zatrzymuje minutnik
;------------------------------------------------------------------------
MINUTNIK:
    MOV TH0, #LADUJ0         ; Początkowa wartość timera nr 0
    PUSH PSW                ; Zachowanie
    PUSH ACC                ; Używanych
    MOV A, R0                ; Rejestrów
    PUSH ACC                ; Na stosie
    MOV A, LECI              ; Sprawdź bit LECI
    JZ MINUTNIK_KONIEC               ; Gdy bit LECI = 0, to brak zmiany CZAS_SEC
    DJNZ LICZNIK_50MS, MINUTNIK_KONIEC ; Dekrementuj licznik co 50 ms i sprawdź, czy już minęła 1 sekunda
    MOV LICZNIK_50MS, #20    ; Resetowanie licznika 50 ms

    MOV A, CZAS_SEC         ; Do aktualnych CZAS_SEC (sekundy)
    INC A                   ; Zwiększ o 1 sekundę
    MOV CZAS_SEC, A         ; Zapamiętaj nowy CZAS_SEC
    CJNE A, #60, AKTUALIZUJ_LCD_INTERRUPT ; Jeśli CZAS_SEC != 60, kontynuuj
    MOV CZAS_SEC, #0        ; Jeśli CZAS_SEC == 60, ustaw CZAS_SEC na 0
    INC CZAS_MIN            ; Zwiększ CZAS_MIN o 1 minutę
    MOV A, CZAS_MIN
    CJNE A, #60, AKTUALIZUJ_LCD_INTERRUPT ; Jeśli CZAS_MIN != 60, kontynuuj
    MOV CZAS_MIN, #0        ; Jeśli CZAS_MIN == 60, ustaw CZAS_MIN na 0
    INC CZAS_HOUR           ; Zwiększ CZAS_HOUR o 1 godzinę
    MOV A, CZAS_HOUR
    CJNE A, #13, AKTUALIZUJ_LCD_INTERRUPT ; Jeśli CZAS_HOUR != 13, kontynuuj
    MOV CZAS_HOUR, #1       ; Jeśli CZAS_HOUR == 13, ustaw CZAS_HOUR na 1
AKTUALIZUJ_LCD_INTERRUPT:
    LCALL    AKTUALIZUJ_LCD_MAIN ; Zaktualizuj wyświetlacz po zmianie czasu
MINUTNIK_KONIEC:
    POP ACC                 ; Odtworzenie
    MOV R0, A               ; Używanych
    POP ACC                 ; Rejestrów
    POP PSW                 ; Ze stosu
    RETI                    ; Wyjście z przerwania

PISZ_ZNAK:
    LCALL    LCD_GOTOWY
    PUSH    ACC
    PUSH    DPL
    PUSH    DPH
    MOV    DPTR,#LCDWD+0FF00H
    MOVX    @DPTR,A
    POP    DPH
    POP    DPL
    POP    ACC
    RET
LCD_GOTOWY:
    PUSH    ACC
    PUSH    DPH
    PUSH    DPL
    MOV    DPTR,#LCDRC+0FF00H
CZEKAJ:
    MOVX    A,@DPTR
    JB    ACC.7,CZEKAJ
    POP    DPH
    POP    DPL
    POP    ACC
    RET

PISZ_DEC2:
    PUSH    ACC
    PUSH    B
    MOV    B, #10
    DIV    AB
    ADD    A, #30H
    LCALL   PISZ_ZNAK
    MOV     A, B
    ADD     A, #30H
    LCALL   PISZ_ZNAK
    POP     B
    POP     ACC
    RET
