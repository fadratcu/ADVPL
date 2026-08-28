#Include "PROTHEUS.CH"
#Include "TOPCONN.CH"

//================================================================================================================
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  @Autor  : Fabio Dratcu
//  @Data   : 29/08/2025
//  @Rotina : LIBERAR DESCONTO PROMOCIONAL - HEAD DE VENDAS
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//================================================================================================================
User Function DHLiberaPromo()
    Local aArea      := GetArea()
    Local aAreaSC5   := Nil
    Local cUsr       := Upper(AllTrim(__cUserId))
    Local cMV        := AllTrim(SuperGetMV("MV_XLIPRO", , "")) // Ex.: "USR1,USR2" ou "USR1; USR2"
    Local cStatus    := ""

    // Garante contexto do pedido de venda
    // If ! FWIsInCallStack("MATA410")
    //     MsgAlert("Esta rotina deve ser executada a partir do MATA410 (Pedido de Venda).")
    //     Return .F.
    // EndIf

    If !cUsr $ cMV
        MsgAlert("Usuário sem permissão (verifique MV_XLIPRO).")
        Return .F.
    EndIf

    DbSelectArea("SC5")
    aAreaSC5 := SC5->(GetArea())

    If SC5->(EoF()) .Or. Empty(SC5->C5_NUM)
        MsgAlert("Não foi posicionado nenhum pedido. Selecione um pedido e tente novamente.")
        RestArea(aAreaSC5)
        RestArea(aArea)
        Return .F.
    EndIf

    cStatus := Upper(AllTrim(SC5->C5_XSTATUS))


    If !Empty(cStatus) .And. ( cStatus $ "ENT|COL" )
        MsgAlert("Pedido já finalizado; não permite liberação de desconto promocional.")
        RestArea(aAreaSC5)
        RestArea(aArea)
        Return .F.
    EndIf

    If SC5->(RecLock("SC5", .F.))
        SC5->C5_XPERPRO := "S"
        SC5->(MsUnLock())
        DbCommit()

        FWAlertInfo("Desconto promocional liberado no pedido " + AllTrim(SC5->C5_NUM))

        RestArea(aAreaSC5)
        RestArea(aArea)
        Return .T.
    Else
        MsgStop("Não foi possível travar o registro do pedido (SC5). Tente novamente.")
        RestArea(aAreaSC5)
        RestArea(aArea)
        Return .F.
    EndIf
Return .F.
