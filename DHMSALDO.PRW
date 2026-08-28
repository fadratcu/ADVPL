#INCLUDE "PROTHEUS.CH"
#INCLUDE "TopConn.ch"
#INCLUDE "TBICONN.CH"
#include "RWMAKE.CH"

//==========================================================================================================
// Funcao     : U_DHMSALDO() 
// Objetivo   : CLIENTE COM MAIOR SALDO MAIOR QUE BLOQUEIO DE ALCADA
// Autor-Data : FABIO DRATCU
//==========================================================================================================
User Function DHMSALDO() 
    Local _cAliasE1    := GetNextAlias()
    Local _cAliasE5    := GetNextAlias()
    Local cQryA1       := ""
    Local _XALCAUM     := Val("1.3")
    Local cQryE5       := ""
    Local cQryE1       := ""
    Local cAtraso      := "15"
    Local cUltimo      := VAL("180")
    Local dDataBase    := Date()
    Local dDataLim     := dDataBase - cUltimo
    Local cDataLimSQL  := DtoS(dDataLim)
    Local cMaxAtraso   := VAL("180")
    Local dDataAtraso  := dDataBase - cMaxAtraso
    Local cDataLimAtraso := DtoS(dDataAtraso)
    Private _aRetJob   := {}
    Private _dDatLim   := ""
    Private _cAliasA1  := ""


    RpcSetType(3) 
    RpcSetEnv('01','01',,"","FIN","DHMSALDO",{"SE1","SE5","SA1"})
    InitPublic()
    SetsDefault()

    _cAliasA1 := GetNextAlias()

    cQryA1 := " SELECT * " + CRLF
    cQryA1 += " FROM " + RetSqlName("SA1") + " SA1 (NOLOCK) " + CRLF
    cQryA1 += " WHERE SA1.A1_MSBLQL = '2' " + CRLF
    cQryA1 += " AND SA1.D_E_L_E_T_ = '' " + CRLF
    cQryA1 += " AND SA1.A1_MSALDO > SA1.A1_XBLQALC " + CRLF
    cQryA1 += " ORDER BY SA1.A1_COD " + CRLF

    If Select(_cAliasA1) > 0
        (_cAliasA1)->(DbCloseArea())
    EndIf
    TCQUERY cQryA1 NEW ALIAS (_cAliasA1)

    cQryE1 := " SELECT DISTINCT * FROM SE1010 SE1 (NOLOCK) " + CRLF
    cQryE1 += " WHERE SE1.E1_CLIENTE = '" + (_cAliasA1)->A1_COD + "' " + CRLF
    cQryE1 += " AND SE1.E1_LOJA =  '" + (_cAliasA1)->A1_LOJA + "' " + CRLF 
    cQryE1 += " AND SE1.E1_BAIXA > DATEADD(DAY, " + cValToChar(cAtraso) + ", SE1.E1_VENCREA) " + CRLF 
    cQryE1 += " AND SE1.E1_VENCREA <= '" + cDataLimAtraso + "' " + CRLF
    cQryE1 += " AND TRIM(E1_HIST) NOT IN ('SAC' , 'VENDA DEMONSTRACAO' ,'DEMONSTRACAO') " + CRLF
    cQryE1 += " AND SE1.D_E_L_E_T_ = '' " + CRLF
    cQryE1 += " AND SE1.E1_TIPO IN ('NF','RA') " + CRLF

    If Select(_cAliasE1) > 0
        (_cAliasE1)->(DbCloseArea())
    EndIf
    TCQUERY cQryE1 NEW ALIAS (_cAliasE1)

    cQryE5 := " SELECT DISTINCT * FROM SE5010 SE5 (NOLOCK) " + CRLF
    cQryE5 += " WHERE SE5.E5_CLIFOR = '" + (_cAliasA1)->A1_COD + "' " + CRLF
    cQryE5 += " AND SE5.E5_LOJA =  '" + (_cAliasA1)->A1_LOJA + "' " + CRLF 
    cQryE5 += " AND SE5.E5_DATA =  ( " + CRLF
    cQryE5 += "     SELECT MAX(E5_DATA) FROM SE5010 SE5A (NOLOCK) " + CRLF
    cQryE5 += "     WHERE SE5A.E5_FILIAL = '' " + CRLF
    cQryE5 += "     AND SE5A.E5_TIPO NOT IN ('IR-','CF-','CS-','IS-','IN-','PI-','NCC','NDC','RT','PA','RA') " + CRLF
    cQryE5 += "     AND SE5A.E5_RECPAG = 'R' " + CRLF
    cQryE5 += "     AND SE5A.E5_TIPODOC NOT IN ('RA','ES','JR','MT','CP','DC') " + CRLF
    cQryE5 += "     AND SE5A.E5_CLIFOR = '" + (_cAliasA1)->A1_COD + "' " + CRLF
    cQryE5 += "     AND SE5A.E5_LOJA =  '" + (_cAliasA1)->A1_LOJA + "' " + CRLF
    cQryE5 += "     AND SE5A.E5_SITUACA <> 'C' " + CRLF
    cQryE5 += "     AND SE5A.D_E_L_E_T_ = '' " + CRLF
    cQryE5 += " ) " + CRLF
    cQryE5 += " AND SE5.E5_DATA <= '" + cDataLimSQL + "' " + CRLF

    If Select(_cAliasE5) > 0
        (_cAliasE5)->(DbCloseArea())
    EndIf
    TCQUERY cQryE5 NEW ALIAS (_cAliasE5)

    DbSelectArea("SA1") 
    SA1->(DbSetOrder(1))		

    While (_cAliasA1)->(! Eof())

        If SA1->(DbSeek(xFilial("SA1") + (_cAliasA1)->A1_COD + (_cAliasA1)->A1_LOJA))
            If !(((_cAliasA1)->A1_COD == (_cAliasE1)->E1_CLIENTE .AND. (_cAliasA1)->A1_LOJA == (_cAliasE1)->E1_LOJA)) .AND. ;
               (!(((_cAliasA1)->A1_COD == (_cAliasE5)->E5_CLIFOR .AND. (_cAliasA1)->A1_LOJA == (_cAliasE5)->E5_LOJA)) .OR. ;
                (_cAliasE5)->E5_DATA < cDataLimSQL)

                Reclock("SA1", .F.)
                SA1->A1_XBLQALC := SA1->A1_MSALDO * _XALCAUM
                SA1->(MsUnlock())
            EndIf
        EndIf

        (_cAliasA1)->(DbSkip())

    EndDo	

    (_cAliasA1)->(DbCloseArea()) 

Return
