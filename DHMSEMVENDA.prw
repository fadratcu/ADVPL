#INCLUDE "PROTHEUS.CH"
#INCLUDE "TopConn.ch"

//==========================================================================================================
// Funcao     : U_DHMSEMVENDA() 
// Objetivo   : CLIENTE COM MAIOR SALDO MAIOR QUE BLOQUEIO DE ALCADA
// Autor-Data : FABIO DRATCU - 05/06/2025
//==========================================================================================================

User Function DHMSEMVENDA()

    Local _cAliasA1 := GetNextAlias()
    Local _cAliasC5 := GetNextAlias()
    Local cQueryA1  := ""
    Local cQueryC5  := ""
    Local dHoje     := Date()
    Local dLimite   := dHoje - 360
    Local cDataLim  := DtoS(dLimite)
    Local cVendedorNovo := "106"
    Local cNomeVendedorNovo := "LIVRE"
    Local aLogAlter := {}

    RpcSetType(3)
    RpcSetEnv("01", "01", , , "FIN", "DHMSEMVENDA", {"SA1", "SC5"})

    cQueryA1 := "SELECT * FROM " + RetSqlName("SA1") + " SA1 (NOLOCK) " + CRLF
    cQueryA1 += "WHERE SA1.D_E_L_E_T_ = '' " + CRLF
    cQueryA1 += "AND SA1.A1_MSBLQL = '2' " + CRLF
    cQueryA1 += "AND SA1.A1_VEND NOT IN ('106','107','400') " + CRLF
    cQueryA1 += "AND SA1.A1_FRANQUI <> '1' " + CRLF
    cQueryA1 += "AND SA1.A1_XPROJET <> '1' " + CRLF
    cQueryA1 += "AND SA1.A1_DTCAD <= '" + cDataLim + "' " + CRLF

    If Select(_cAliasA1) > 0
        (_cAliasA1)->(DbCloseArea())
    EndIf
    TCQuery cQueryA1 NEW ALIAS (_cAliasA1)

    While !(_cAliasA1)->(Eof())

        cQueryC5 := "SELECT COUNT(*) QTD FROM " + RetSqlName("SC5") + " SC5 (NOLOCK) " + CRLF
        cQueryC5 += "WHERE SC5.D_E_L_E_T_ = '' " + CRLF
        cQueryC5 += "AND SC5.C5_EMISSAO >= '" + cDataLim + "' " + CRLF
        cQueryC5 += "AND SC5.C5_CLIENTE = '" + (_cAliasA1)->A1_COD + "' " + CRLF
        cQueryC5 += "AND SC5.C5_LOJACLI    = '" + (_cAliasA1)->A1_LOJA + "' " + CRLF
        cQueryC5 += "AND SC5.C5_TIPO NOT IN  ('B,D') " + CRLF 

        If Select(_cAliasC5) > 0
            (_cAliasC5)->(DbCloseArea())
        EndIf
        TCQuery cQueryC5 NEW ALIAS (_cAliasC5)

        If (_cAliasC5)->QTD == 0
            DbSelectArea("SA1")
            SA1->(DbSetOrder(1))
            If SA1->(DbSeek(xFilial("SA1") + (_cAliasA1)->A1_COD + (_cAliasA1)->A1_LOJA))
                Reclock("SA1", .F.)
                SA1->A1_VEND   := cVendedorNovo
                SA1->A1_VREDUZ := cNomeVendedorNovo 
                MsUnlock()
            EndIf
        EndIf

        (_cAliasC5)->(DbCloseArea())
        (_cAliasA1)->(DbSkip())

    EndDo

    (_cAliasA1)->(DbCloseArea())

Return
