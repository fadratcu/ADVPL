#Include "PROTHEUS.CH"
#Include "TOPCONN.CH"

//================================================================================================================
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 //@Autor Fabio Dratcu
 //@Data  29/08/2025
 //LIBERAR CONFERENCIA -->  SUPERVISORA LOGISTICA
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//================================================================================================================

User Function DHLibConf()
    Local aArea := GetArea()
    Local cUsr  := Upper(AllTrim(__cUserId))
    Local cMV   := SuperGetMV("MV_XLICON", , "")
    Local cStatus    := ""



    If !cUsr $ cMV
        MsgAlert("Usuário sem Permissão")
        Return .F.
    EndIf

    DbSelectArea("SC5")
    If SC5->(EoF()) .Or. Empty(SC5->C5_NUM)
        MsgAlert("Não foi posicionado nenhum pedido. Selecione um pedido e tente novamente..")
        Return .F.
    EndIf
    
    cStatus := Upper(AllTrim(SC5->C5_XSTATUS))

    If !Empty(cStatus) .And. ( cStatus $ "ENT|COL" )
        MsgAlert("Pedido já finalizado; não permite liberação de conferencia.")
        RestArea(aArea)
        Return .F.
    EndIf


    If SC5->(RecLock("SC5", .F.))
        SC5->C5_XCONF := "N"
        SC5->(MsUnLock())
        DbCommit()
        FWAlertInfo("Conferência liberada no pedido " + AllTrim(SC5->C5_NUM))
        RestArea(aArea)
        Return .T.
    Else
        MsgStop("Não foi possível travar o registro do pedido (SC5).")
    EndIf

    RestArea(aArea)
Return .F.


