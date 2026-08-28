#INCLUDE "PROTHEUS.CH"
#INCLUDE "PRTOPDEF.CH"
/*/{Protheus.doc} MTVIEWB2
Ponto de Entrada para controle de acesso à visualização de saldos (F4) no cadastro de produtos.
Esta rotina bloqueia o acesso à tela de saldos físicos e financeiros do produto para:
- Usuários cujo ID (login) comece com "XYZ"
- Usuários listados no parâmetro MV_XBLQSB2 (lista de logins bloqueados, separados por vírgula)
- Fora do período de inventário, todos os demais usuários têm acesso normal; durante o
  período de inventário (20/12 a 06/01), só os usuários listados no parâmetro MV_XLIBSB2
  continuam com acesso liberado
@type    User Function
@author  Fabio Dratcu
@since   25/07/2025
@version 1.1
@obs     Implementado para restringir acesso de usuários não autorizados à tela de estoque via F4.
         Listas de usuários bloqueados/liberados configuradas via parametros MV_XBLQSB2 e
         MV_XLIBSB2 (SX6) - nao ficam hardcoded no fonte.
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

    //Bloqueio de consulta durante o inventário (lista de liberados no MV_XLIBSB2)
    If (nMes == 12 .AND. nDia >= 20) .OR. (nMes == 1 .AND. nDia <= 6)
        If !("," + cUserID + "," $ cLiberados)
            MsgStop("Consulta de saldos bloqueada durante o período de inventário.", "Acesso Negado")
            Return .F.
        EndIf
    EndIf

Return .T.
