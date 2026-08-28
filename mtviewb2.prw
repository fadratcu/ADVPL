#INCLUDE "PROTHEUS.CH"
#INCLUDE "PRTOPDEF.CH"
/*/{Protheus.doc} MTVIEWB2
Ponto de Entrada para controle de acesso à visualização de saldos (F4) no cadastro de produtos.
Esta rotina bloqueia o acesso à tela de saldos físicos e financeiros do produto para:
- Usuários cujo ID (login) comece com "XYZ"
- Usuários listados no parâmetro MV_XBLQSB2 (lista de logins bloqueados, separados por vírgula)
- Fora do período de inventário, todos os demais usuários têm acesso normal; durante o
  período de inventário configurado no parâmetro MV_XDTSB2 (formato "DD/MM-DD/MM"), só os
  usuários listados no parâmetro MV_XLIBSB2 continuam com acesso liberado
@type    User Function
@author  Fabio Dratcu
@since   25/07/2025
@version 1.3
@obs     Implementado para restringir acesso de usuários não autorizados à tela de estoque via F4.
         Listas de usuários bloqueados/liberados configuradas via parametros MV_XBLQSB2 e
         MV_XLIBSB2 (SX6). Periodo de inventario configurado via MV_XDTSB2, formato
         "DD/MM-DD/MM" (ex.: "20/12-06/01" - trata sozinho a virada de ano). Nada disso
         fica hardcoded no fonte. Se o MV_XDTSB2 estiver vazio/mal formatado, avisa com
         MsgAlert em vez de falhar em silencio, mas NAO bloqueia o acesso normal por causa
         disso - um parametro mal configurado nao pode travar a consulta de saldo pra
         todo mundo o ano inteiro.
@see     Utilizada automaticamente ao pressionar F4 no campo B1_COD.
@return  .F. para bloquear a visualização | .T. para permitir
/*/
User Function MTVIEWB2()
    Local cUserID     := Lower(AllTrim(cUserName))
    //*** guarda entre virgulas nas pontas pra evitar falso positivo de
    //*** substring (ex.: "ana" nao pode bater dentro de "juliana")
    Local cBloqueados := "," + Lower(AllTrim(SuperGetMV("MV_XBLQSB2", , ""))) + ","
    Local cLiberados  := "," + Lower(AllTrim(SuperGetMV("MV_XLIBSB2", , ""))) + ","
    Local dHoje := Date()
    Local nMes := Month(dHoje)
    Local nDia := Day(dHoje)

    //*** periodo de inventario configuravel via MV_XDTSB2, formato "DD/MM-DD/MM".
    //*** default (se o parametro nao existir ainda) mantem o mesmo periodo que
    //*** ja estava hardcoded antes: 20/12 a 06/01.
    Local cPeriodo := AllTrim(SuperGetMV("MV_XDTSB2", , "20/12-06/01"))
    Local nPosSep  := At("-", cPeriodo)
    Local cDtIni   := ""
    Local cDtFim   := ""
    Local nDiaIni  := 0
    Local nMesIni  := 0
    Local nDiaFim  := 0
    Local nMesFim  := 0
    Local nAtual   := (nMes * 100) + nDia
    Local nDtIni   := 0
    Local nDtFim   := 0
    Local lPeriodo := .F.

    // Bloqueia usuários que começam com "XYZ"
    If Left(cUserID, 3) == "XYZ"
        MsgStop("Você não tem permissão para consultar saldos de produtos.", "Acesso Negado")
        Return .F.
    EndIf

    // Bloqueia usuários específicos (lista no parametro MV_XBLQSB2)
    If "," + cUserID + "," $ cBloqueados
        MsgStop("Você não tem permissão para consultar saldos de produtos.", "Acesso Negado")
        Return .F.
    EndIf

    //*** monta o periodo de inventario a partir do parametro MV_XDTSB2. Se o
    //*** parametro estiver vazio ou fora do formato "DD/MM-DD/MM", NAO fica em
    //*** silencio: avisa com um MsgAlert bem visivel (pra alguem notar e
    //*** corrigir o SX6) e segue SEM bloquear o acesso normal - um parametro
    //*** mal configurado nao pode derrubar a consulta de saldo da empresa
    //*** inteira o ano inteiro por causa de um erro de digitacao.
    If Empty(cPeriodo) .Or. nPosSep == 0
        MsgAlert("Parametro MV_XDTSB2 (periodo de inventario) esta vazio ou mal configurado." + CRLF + ;
            "Formato esperado: DD/MM-DD/MM (ex.: 20/12-06/01)." + CRLF + CRLF + ;
            "O bloqueio de consulta durante o inventario NAO esta ativo ate corrigir.", "Atencao - Configuracao")
    Else
        cDtIni := AllTrim(SubStr(cPeriodo, 1, nPosSep - 1))
        cDtFim := AllTrim(SubStr(cPeriodo, nPosSep + 1))

        If At("/", cDtIni) > 0 .And. At("/", cDtFim) > 0
            nDiaIni := Val(SubStr(cDtIni, 1, At("/", cDtIni) - 1))
            nMesIni := Val(SubStr(cDtIni, At("/", cDtIni) + 1))
            nDiaFim := Val(SubStr(cDtFim, 1, At("/", cDtFim) - 1))
            nMesFim := Val(SubStr(cDtFim, At("/", cDtFim) + 1))

            //*** validacao basica dos numeros extraidos - se vier algo tipo
            //*** "00/00" ou "40/13" (dia/mes invalido), tambem avisa em vez de
            //*** deixar passar batido como se fosse um periodo valido.
            If nDiaIni >= 1 .And. nDiaIni <= 31 .And. nMesIni >= 1 .And. nMesIni <= 12 .And. ;
               nDiaFim >= 1 .And. nDiaFim <= 31 .And. nMesFim >= 1 .And. nMesFim <= 12

                nDtIni := (nMesIni * 100) + nDiaIni
                nDtFim := (nMesFim * 100) + nDiaFim

                //*** se a data final for "menor" que a inicial, o periodo cruza a
                //*** virada do ano (ex.: 20/12 a 06/01) - senao, e um periodo normal
                //*** dentro do mesmo ano.
                If nDtIni <= nDtFim
                    lPeriodo := nAtual >= nDtIni .And. nAtual <= nDtFim
                Else
                    lPeriodo := nAtual >= nDtIni .Or. nAtual <= nDtFim
                EndIf
            Else
                MsgAlert("Parametro MV_XDTSB2 (periodo de inventario) tem data invalida: '" + cPeriodo + "'." + CRLF + ;
                    "Formato esperado: DD/MM-DD/MM (ex.: 20/12-06/01)." + CRLF + CRLF + ;
                    "O bloqueio de consulta durante o inventario NAO esta ativo ate corrigir.", "Atencao - Configuracao")
            EndIf
        Else
            MsgAlert("Parametro MV_XDTSB2 (periodo de inventario) esta fora do formato esperado: '" + cPeriodo + "'." + CRLF + ;
                "Formato esperado: DD/MM-DD/MM (ex.: 20/12-06/01)." + CRLF + CRLF + ;
                "O bloqueio de consulta durante o inventario NAO esta ativo ate corrigir.", "Atencao - Configuracao")
        EndIf
    EndIf

    //Bloqueio de consulta durante o inventário (lista de liberados no MV_XLIBSB2)
    If lPeriodo
        If !("," + cUserID + "," $ cLiberados)
            MsgStop("Consulta de saldos bloqueada durante o período de inventário.", "Acesso Negado")
            Return .F.
        EndIf
    EndIf

Return .T.
