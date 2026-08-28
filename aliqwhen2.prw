#Include 'Protheus.ch'

//---------------------------------------------------------------------------------
// Rotina | ALIQWHEN2         | Autor | Fabio Dratcu        | Data |    16/09/2024			
//---------------------------------------------------------------------------------
// Descr. | Fonte Customizado para bloquear edição do Campo Valor Total do Pedido																		
//        | de compras
//        | Basta colocar esse Fonte no campo X3_WHEN.
//---------------------------------------------------------------------------------
// Uso    | DAYHOME
//---------------------------------------------------------------------------------

User Function ALIQWHEN2()

Local lRet      := .T.
Local nUsrLiber2 := RetCodUsr()
Local ncUser2    := Getmv("MV_BLQTOT")

IF INCLUI .OR. ALTERA
    
    IF !(nUsrLiber2$ncUser2)
    
        lRet := .F.
    
    ENDIF

ENDIF


Return lRet


