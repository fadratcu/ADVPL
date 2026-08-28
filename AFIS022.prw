#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOPCONN.CH"

//===================================================================================
// NOTA (versao publica/exemplo): esta e uma copia do AFIS022.prw real, com os
// dados que identificam a infraestrutura interna da empresa substituidos por
// placeholders genericos, pra poder ser publicada num repositorio publico
// sem expor detalhes da rede interna:
//   - "SEUSERVIDOR"    -> era o IP interno (faixa privada 192.168.x.x) do
//                         servidor de arquivos onde ficam os prints
//   - "SUAEMPRESA_TSS" -> era o nome do banco de dados do TSS, que incluia
//                         o nome da empresa
// Se for reaproveitar este codigo em outro ambiente, troque esses dois
// placeholders (e o caminho "G:\Departamentos\Sintegra", se quiser) pelos
// valores reais do seu ambiente antes de compilar.
//===================================================================================

//===================================================================================
// Funcao     : AFIS022
// Objetivo   : Consulta situacao cadastral da IE do cliente/fornecedor na Sefaz
// Autor-Data : Fabio Dratcu - 03/08/2026
// Alteracao  : Fabio Dratcu - 27/08/2026 - Incluido fluxo de confirmacao manual
//              (print exigido, guardado na pasta de rede Departamentos\Sintegra)
//              para os casos em que a Sefaz/TSS nao responde: (1) apos esgotar
//              as tentativas de retry, e (2) quando a ENTIDADE do TSS nao e
//              encontrada no SPED001.
// Alteracao  : Fabio Dratcu - 28/08/2026 - IE baixada (situacao "0") mas com
//              data de baixa efetivamente registrada na Sefaz nao bloqueia mais:
//              so alerta e libera (cCodRet "100"). Aceita o risco residual de
//              uma baixa "em processo" tambem vir com data preenchida, porque,
//              se a IE for realmente irregular, a emissao real da NFe (que so
//              acontece alguns dias depois da liberacao do pedido) ainda vai
//              travar com "Irregularidade Fiscal" direto na Sefaz - funcionando
//              como uma segunda camada de seguranca fora do escopo do AFIS022.
// Descricao  : Retorna um objeto com:
//              lOk           -> .T. se houve comunicacao com o TSS/Sefaz OU se o
//                                usuario confirmou manualmente via print (cCodRet=103)
//              lIsento       -> .T. se a consulta foi feita em modo isento (sem IE)
//              lIEDivergente -> .T. se a IE/CNPJ/CPF informados nao conferem com a Sefaz,
//                                ou cliente isento com IE ATIVA na Sefaz
//              cSituacao     -> Situacao (codigo) retornada pela Sefaz: "0"=Nao Habilitado / "1"=Habilitado
//              cIE           -> IE retornada pela Sefaz para o registro encontrado
//              cCNPJ         -> CNPJ retornado pela Sefaz para o registro encontrado
//              cCPF          -> CPF retornado pela Sefaz para o registro encontrado
//              dBaixa        -> Data de baixa, se houver
//              cIEAtual      -> IE atual, se a informada estiver desatualizada
//              cIEUnica      -> IE unica, se aplicavel
//              cRazao        -> Razao social retornada pela Sefaz
//              cMsg          -> Mensagem complementar ou de erro
//              cCodRet       -> "100"=Habilitado (ou isento confirmado: nao encontrado
//                                     ou encontrado porem baixado na Sefaz; ou nao-isento
//                                     baixado MAS com data de baixa informada - libera com alerta)
//                               "101"=Nao habilitado/baixado/suspenso, SEM data de baixa
//                                     informada (quando NAO e isento)
//                               "102"=IE/CNPJ/CPF informados divergem do que a Sefaz retornou,
//                                     ou cliente isento com IE ATIVA na Sefaz
//                               "103"=Liberado mediante CONFIRMACAO MANUAL do usuario (print
//                                     exigido na tela, salvo na pasta de rede Departamentos\
//                                     Sintegra) - usado quando: (a) Sefaz/TSS sem comunicacao
//                                     apos retry, (b) entidade do TSS nao configurada no
//                                     SPED001, ou (c) Sefaz respondeu "nao encontrado" (000)
//                                     mas o usuario confirmou visualmente que a IE existe
//                               "000"=Nao encontrado (quando NAO e isento) - usuario NAO
//                                     confirmou a conferencia manual (operacao bloqueada)
//                               "999"=Falha real de comunicacao/configuracao - usuario
//                                     NAO confirmou a conferencia manual (operacao bloqueada)
//===================================================================================
User Function AFIS022(cUF, cCNPJ, cCPF, cIE)

	Local cURL := AllTrim(GetNewPar("MV_SPEDURL", ""))
	Local lValidaIE   := SuperGetMV("MV_XVALIE", NIL, .T.)  //*** .T. = ligado por padrao
	Local cIdEnt      := ""
	Local cAlias      := GetNextAlias()
	Local cQuery      := ""
	Local oWS         := Nil
	Local oCad        := Nil
	Local oRet        := JsonObject():New()
	Local cSituacao   := ""
	Local cIEInform   := ""
	Local cCNPJInform := ""
	Local cCPFInform  := ""
	Local lIsento     := .F.
	Local nMaxTentativas := 3
	Local nTentativa      := 0
	Local lConsultaOk     := .F.

	Default cUF   := ""
	Default cCNPJ := ""
	Default cCPF  := ""
	Default cIE   := ""

	oRet["lOk"]           := .F.
	oRet["lIsento"]       := .F.
	oRet["lIEDivergente"] := .F.
	oRet["cSituacao"]     := ""
	oRet["cIE"]           := ""
	oRet["cCNPJ"]         := ""
	oRet["cCPF"]          := ""
	oRet["dBaixa"]        := CToD("")
	oRet["cIEAtual"]      := ""
	oRet["cIEUnica"]      := ""
	oRet["cRazao"]        := ""
	oRet["cMsg"]          := ""
	oRet["cCodRet"]       := "999"

	cUF   := Upper(AllTrim(cUF))
	cCNPJ := AllTrim(cCNPJ)
	cCPF  := AllTrim(cCPF)
	cIE   := AllTrim(cIE)


	//*** kill switch - se o parametro MV_XVALIE estiver "N"/.F., a validacao
	//*** e desligada e sempre retorna "100" (liberado), sem consultar a Sefaz.
	If !lValidaIE
		oRet["lOk"]     := .T.
		oRet["cCodRet"] := "100"
		oRet["cMsg"]    := "Validacao de IE desativada (MV_XVALIE = N)."
		Return oRet
	EndIf

	//*** Guarda os valores originais informados (antes de sanitizar) para as
	//*** mensagens de erro ficarem mais legiveis pro usuario
	cCNPJInform := cCNPJ
	cCPFInform  := cCPF
	cIEInform   := cIE

	lIsento := Empty(cIE) .Or. Upper(cIE) == "ISENTO"
	If lIsento
		cIE := ""
	Else
		cIE := AFIS022SOUNM(cIE)
	EndIf

	oRet["lIsento"] := lIsento

	While Right(cURL, 1) == "/"
		cURL := SubStr(cURL, 1, Len(cURL) - 1)
	EndDo

	If Empty(cUF)
		oRet["cMsg"]    := "UF nao informada para consulta."
		oRet["cCodRet"] := "000"
		Return oRet
	EndIf

	If Empty(cCNPJ) .And. Empty(cCPF)
		oRet["cMsg"]    := "CNPJ ou CPF deve ser informado para consulta."
		oRet["cCodRet"] := "000"
		Return oRet
	EndIf

	cQuery := " SELECT ISNULL(MAX(ID_ENT),'') ENTIDADE "
	cQuery += " FROM SUAEMPRESA_TSS.dbo.SPED001 SPED WITH (NOLOCK) "
	cQuery += " WHERE ENTATIV = 'S' "
	cQuery += " AND CNPJ = '" + AllTrim(SM0->M0_CGC) + "' "
	cQuery += " AND SPED.D_E_L_E_T_ = '' "

	If Select(cAlias) > 0
		(cAlias)->(DbCloseArea())
	EndIf

	TcQuery cQuery New Alias (cAlias)

	If !(cAlias)->(Eof())
		cIdEnt := AllTrim((cAlias)->ENTIDADE)
	EndIf

	(cAlias)->(DbCloseArea())

	If Empty(cIdEnt)

		//*** Aqui a falha nao e da Sefaz, e de configuracao (entidade do TSS
		//*** nao cadastrada/ativa no SPED001 para o CNPJ da empresa) - mas o
		//*** efeito pratico pro usuario e o mesmo (nao consegue emitir). A
		//*** pedido do Fabio (27/08/2026), tambem oferece a confirmacao manual
		//*** via print aqui, com a mesma exigencia de conferencia visual.
		oRet["cMsg"] := "Entidade nao encontrada no SPED001 para o CNPJ da empresa."

		If AFIS022PRINT(cUF, cCNPJ, cCPF, cIE)
			oRet["lOk"]     := .T.
			oRet["cCodRet"] := "103"
			oRet["cMsg"]    += " IE liberada mediante conferencia manual do usuario (print exigido, salvo na pasta de rede)."
		Else
			oRet["cCodRet"] := "999"
			oRet["cMsg"]    += " Usuario nao confirmou a conferencia manual do print - operacao bloqueada."
		EndIf

		Return oRet
	EndIf

	//*** Loop de tentativas - o servico da Sefaz/TSS e sabidamente instavel
	//*** (erros intermitentes tipo "005 - Consulta nao disponivel" ou
	//*** "006 - Erro nao catalogado" que somem sozinhos minutos depois).
	While nTentativa < nMaxTentativas .And. !lConsultaOk

		nTentativa++

		If nTentativa > 1
			ConOut("AFIS022 - Tentativa " + AllTrim(Str(nTentativa)) + " de " + AllTrim(Str(nMaxTentativas)) + "...")
			Sleep(1500)
		EndIf

		If !AFIS022ISREADY(cURL)
			oRet["cMsg"]    := "TSS indisponivel ou sem comunicacao (tentativa " + AllTrim(Str(nTentativa)) + ")."
			oRet["cCodRet"] := "999"
			Loop
		EndIf

		oWS := WsNFeSBra():New()

		oWS:cUserToken := "TOTVS"
		oWS:cID_ENT    := cIdEnt
		oWS:cUF        := cUF
		oWS:cCNPJ      := cCNPJ
		oWS:cCPF       := cCPF
		oWS:cIE        := cIE
		oWS:_URL       := cURL + "/NFeSBRA.apw"

		//*** IMPORTANTE: o retorno booleano de ConsultaContribuinte() NAO distingue
		//*** "falha real" de "nao encontrou nada" (resultado legitimo para isento).
		//*** So tentamos ler o resultado; erro de acesso real cai no Recover.
		oWS:ConsultaContribuinte()

		Begin Sequence

			If Len(oWS:oWSCONSULTACONTRIBUINTERESULT:oWSNFECONSULTACONTRIBUINTE) == 0

				If lIsento
					oRet["cMsg"]    := "Cliente isento confirmado - nenhum registro de ICMS encontrado para este CNPJ na Sefaz."
					oRet["cCodRet"] := "100"
				Else
					oRet["cMsg"]    := "Contribuinte nao encontrado no cadastro da Sefaz."
					oRet["cCodRet"] := "000"
				EndIf

				oRet["lOk"] := .T.
				lConsultaOk := .T.  //*** resposta valida (vazio de verdade) - nao repete
			Else
				oCad        := oWS:oWSCONSULTACONTRIBUINTERESULT:oWSNFECONSULTACONTRIBUINTE[1]
				oRet["lOk"] := .T.
				lConsultaOk := .T.
			EndIf

		Recover

			oRet["cMsg"]    := "Falha na comunicacao com o TSS/Sefaz ao consultar o contribuinte (tentativa " + AllTrim(Str(nTentativa)) + ")."
			oRet["cCodRet"] := "999"
			//*** nao seta lConsultaOk - deixa tentar de novo, se ainda houver tentativas

		End Sequence

	EndDo

	If !lConsultaOk

		//*** Esgotou as tentativas de retry sem conseguir falar com a Sefaz/TSS.
		//*** A pedido do Fabio (27/08/2026): em vez de so avisar e travar, exige
		//*** que o usuario anexe um print da consulta manual (Sintegra/Sefaz),
		//*** salvo na pasta de rede Departamentos\Sintegra, e confirme
		//*** explicitamente que verificou a situacao da IE.
		If AFIS022PRINT(cUF, cCNPJ, cCPF, cIE)
			oRet["lOk"]     := .T.
			oRet["cCodRet"] := "103"
			oRet["cMsg"]    := "Sefaz sem comunicacao apos " + AllTrim(Str(nMaxTentativas)) + " tentativas - IE liberada mediante conferencia manual do usuario (print exigido, salvo na pasta de rede)."
		Else
			oRet["cMsg"] += " Usuario nao confirmou a conferencia manual do print - operacao bloqueada."
		EndIf

		Return oRet
	EndIf

	If oCad == Nil

		//*** cCodRet ja foi setado dentro do loop: "100" (isento confirmado -
		//*** resultado valido, nao pede print) ou "000" (nao-isento, contribuinte
		//*** nao encontrado na Sefaz). A pedido do Fabio (27/08/2026), o "000"
		//*** tambem passa pela confirmacao manual via print, pelo mesmo motivo
		//*** dos casos "999": o cadastro da Sefaz pode estar desatualizado/
		//*** divergente, e o operador pode ter uma prova visual de que a IE existe.
		If oRet["cCodRet"] == "000"

			If AFIS022PRINT(cUF, cCNPJ, cCPF, cIE)
				oRet["cCodRet"] := "103"
				oRet["cMsg"]    := "Contribuinte nao encontrado no cadastro da Sefaz, mas liberado mediante conferencia manual do usuario (print exigido, salvo na pasta de rede)."
			Else
				oRet["cMsg"] += " Usuario nao confirmou a conferencia manual do print - operacao bloqueada."
			EndIf

		EndIf

		Return oRet
	EndIf

	//*** blindagem contra campos NIL
	oRet["cSituacao"] := IIf(ValType(oCad:cSITUACAO)    == "C", AllTrim(oCad:cSITUACAO),    "")
	oRet["cIE"]       := IIf(ValType(oCad:cIE)          == "C", AllTrim(oCad:cIE),          "")
	oRet["cCNPJ"]     := IIf(ValType(oCad:cCNPJ)        == "C", AllTrim(oCad:cCNPJ),        "")
	oRet["cCPF"]      := IIf(ValType(oCad:cCPF)         == "C", AllTrim(oCad:cCPF),         "")
	oRet["cIEAtual"]  := IIf(ValType(oCad:cIEATUAL)     == "C", AllTrim(oCad:cIEATUAL),     "")
	oRet["cIEUnica"]  := IIf(ValType(oCad:cIEUNICA)     == "C", AllTrim(oCad:cIEUNICA),     "")
	oRet["cRazao"]    := IIf(ValType(oCad:cRAZAOSOCIAL) == "C", AllTrim(oCad:cRAZAOSOCIAL), "")

	If ValType(oCad:dBAIXA) == "D"
		oRet["dBaixa"] := oCad:dBAIXA
	EndIf

	cSituacao := AllTrim(oRet["cSituacao"])

	//*** Isento + IE encontrada ATIVA ("1") na Sefaz -> inconsistencia real, bloqueia.
	//*** Isento + IE encontrada BAIXADA ("0") na Sefaz -> cenario operacional
	//*** valido (cliente emite como isento mesmo com IE baixada) - tratado no Do Case.
	If lIsento .And. !Empty(oRet["cIE"]) .And. cSituacao == "1"
		oRet["lIEDivergente"] := .T.
		oRet["cMsg"] := "Cliente cadastrado como ISENTO, mas a Sefaz retornou uma IE ATIVA para este CNPJ (" + oRet["cIE"] + "). Verifique o cadastro."
	EndIf

	If !lIsento .And. !Empty(cIE) .And. !Empty(oRet["cIE"]) .And. cIE != AFIS022SOUNM(oRet["cIE"])
		oRet["lIEDivergente"] := .T.
		oRet["cMsg"] := "IE informada (" + cIEInform + ") nao confere com a IE cadastrada na Sefaz (" + oRet["cIE"] + ") para o CNPJ/CPF informado."
	EndIf

	If !Empty(cCNPJ) .And. !Empty(oRet["cCNPJ"]) .And. cCNPJ != oRet["cCNPJ"]
		oRet["lIEDivergente"] := .T.
		oRet["cMsg"] := "CNPJ informado (" + cCNPJInform + ") nao confere com o CNPJ cadastrado na Sefaz (" + oRet["cCNPJ"] + ") para a IE informada."
	EndIf

	If !Empty(cCPF) .And. !Empty(oRet["cCPF"]) .And. cCPF != oRet["cCPF"]
		oRet["lIEDivergente"] := .T.
		oRet["cMsg"] := "CPF informado (" + cCPFInform + ") nao confere com o CPF cadastrado na Sefaz (" + oRet["cCPF"] + ") para a IE informada."
	EndIf

	ConOut("AFIS022 - Situacao (codigo) retornada pela Sefaz: [" + cSituacao + "] - Isento: " + IIf(lIsento, "SIM", "NAO") + " - Tentativas: " + AllTrim(Str(nTentativa)))

	Do Case
		Case oRet["lIEDivergente"]
			oRet["cCodRet"] := "102"

		Case lIsento .And. cSituacao == "0"
			oRet["cCodRet"] := "100"
			oRet["cMsg"]    := "Cliente isento - IE encontrada esta baixada na Sefaz, mas isso e aceito para emissao como isento."

		//*** IE baixada (situacao "0") MAS com data de baixa efetivamente
		//*** registrada na Sefaz - nao bloqueia mais, so alerta e libera.
		//*** Fabio Dratcu - 28/08/2026: risco residual (uma baixa "em
		//*** processo" tambem pode vir com data preenchida) aceito de proposito
		//*** - se a IE for realmente irregular, a emissao real da NFe (que so
		//*** acontece alguns dias depois da liberacao do pedido) ainda vai
		//*** travar com "Irregularidade Fiscal" direto na Sefaz. Se NAO tiver
		//*** data de baixa preenchida, continua caindo no "Case cSituacao == '0'"
		//*** logo abaixo e bloqueando (cCodRet "101"), sem alteracao nenhuma.
		Case !lIsento .And. cSituacao == "0" .And. !Empty(oRet["dBaixa"])
			oRet["cCodRet"] := "100"
			oRet["cMsg"]    := "IE baixada na Sefaz em " + DToC(oRet["dBaixa"]) + " - liberado para prosseguir. A emissao real da NFe ainda sera validada pela Sefaz."
			MsgAlert(oRet["cMsg"], "Atencao - IE Baixada")

		Case cSituacao == "1"
			oRet["cCodRet"] := "100"

		Case cSituacao == "0"
			oRet["cCodRet"] := "101"

		Case !Empty(oRet["dBaixa"])
			oRet["cCodRet"] := "101"

		Otherwise
			oRet["cCodRet"] := "000"
			oRet["cMsg"]    := "Codigo de situacao nao reconhecido: [" + cSituacao + "]"
	EndCase

Return oRet

//===================================================================================
// Funcao     : AFIS022PRINT
// Objetivo   : Quando a Sefaz/TSS nao responde (apos retry) ou quando falta
//              configuracao (entidade nao encontrada), obriga o usuario a
//              selecionar um arquivo de imagem (print da consulta manual no
//              Sintegra/Sefaz), SALVO na pasta de rede Departamentos\Sintegra,
//              e confirmar explicitamente que verificou a situacao da IE.
//              O AFIS022 nao copia/grava o arquivo em lugar nenhum - so valida
//              que o caminho escolhido esta dentro dessa pasta de rede, pra
//              garantir que o print fica guardado la (ver validacao de
//              caminho logo apos a checagem de extensao, abaixo).
// Autor-Data : Fabio Dratcu - 27/08/2026
// Alteracao  : Fabio Dratcu - 28/08/2026 - Exige que o print esteja salvo na
//              pasta de rede Departamentos\Sintegra (acessivel via drive
//              mapeado G: ou via UNC direto no servidor SEUSERVIDOR), pra
//              manter os prints guardados.
// Retorno    : .T. = usuario anexou e confirmou / .F. = usuario cancelou
//===================================================================================
Static Function AFIS022PRINT(cUF, cCNPJ, cCPF, cIE)

	Local cArqPrint   := ""
	Local lConfirmado := .F.

	//*** Depois de 3 tentativas com MSDialog customizado (posicao, tamanho e
	//*** complexidade da ACTION dos botoes), o botao OK/Cancelar continuou sem
	//*** aparecer testando via navegador (SmartView/web) - sinal de que o
	//*** problema nao e posicao/sintaxe, e sim suporte limitado a MSDialog com
	//*** multiplos botoes customizados nesse renderizador. Trocado por uma
	//*** sequencia de dialogos "de prateleira" (MsgAlert / cGetFile / ApMsgYesNo)
	//*** que ja sao usados em outras rotinas do proprio ambiente (ex: MT100TOK
	//*** usa ApMsgYesNo) e por isso tem garantia de renderizar certo aqui.

	MsgAlert("Nao foi possivel validar a IE automaticamente na Sefaz-" + cUF + "." + CRLF + CRLF + ;
		"CNPJ/CPF: " + IIf(!Empty(cCNPJ), cCNPJ, cCPF) + "   IE: " + IIf(Empty(cIE), "ISENTO", cIE) + CRLF + CRLF + ;
		"Consulte manualmente no Sintegra (www.sintegra.gov.br) ou no site da Sefaz-" + cUF + "," + CRLF + ;
		"tire um print da tela de confirmacao, SALVE na pasta Departamentos\Sintegra" + CRLF + ;
		"(G:\Departamentos\Sintegra ou \\SEUSERVIDOR\Departamentos\Sintegra)" + CRLF + ;
		"e selecione o arquivo na proxima tela.", ;
		"Confirmacao manual de IE - Sefaz indisponivel")

	//*** O filtro "Imagens (*.jpg;*.jpeg;*.png;*.bmp)" testado nesse widget web
	//*** (SmartView) esconde a listagem inteira - inclusive arquivos .png reais
	//*** que estavam na pasta - sinal de que o parsing de extensoes multiplas
	//*** com ";" nao funciona direito aqui. Como ja validamos a extensao na
	//*** unha logo abaixo, deixamos so "Todos os Arquivos" (que funciona) e a
	//*** validacao pos-selecao garante que so imagem passa.
	//*** cPath ja inicia direto na pasta de rede (Departamentos\Sintegra), pra
	//*** o usuario ja cair no lugar certo pra selecionar (e ter salvo) o print.
	cArqPrint := cGetFile("Todos os Arquivos (*.*)|*.*|", ;
		"Selecione o print da consulta de IE (salvo em Departamentos\Sintegra)", 1, "G:\Departamentos\Sintegra\", .F., GETF_LOCALHARD, .T., .F.)

	If Empty(cArqPrint)
		MsgAlert("Nenhum arquivo selecionado - operacao bloqueada.", "Atencao")
		Return .F.
	EndIf

	//*** o filtro de extensao do cGetFile nao esta sendo respeitado nesse
	//*** ambiente (navegador/SmartView) - ja foi possivel selecionar um .dll
	//*** em teste. Validando a extensao aqui, na unha, depois da selecao.
	If AScan({".JPG", ".JPEG", ".PNG", ".BMP"}, Upper(SubStr(cArqPrint, RAt(".", cArqPrint)))) == 0
		MsgAlert("O arquivo selecionado nao e uma imagem valida (use .jpg, .jpeg, .png ou .bmp)." + CRLF + ;
			"Arquivo selecionado: " + cArqPrint, "Atencao")
		Return .F.
	EndIf

	//*** exige que o print esteja salvo na pasta de rede compartilhada
	//*** (Departamentos\Sintegra), acessivel via drive mapeado G: ou via UNC
	//*** direto no servidor SEUSERVIDOR - assim o print fica guardado la, sem
	//*** o AFIS022 precisar copiar/gravar o arquivo em lugar nenhum.
	//*** Fabio Dratcu - 28/08/2026.
	If Left(Upper(cArqPrint), 11) <> "G:\SINTEGRA" .AND. Left(Upper(cArqPrint), 36) <> "\\SEUSERVIDOR"
		MsgAlert("O print precisa ser salvo na pasta Departamentos\Sintegra" + CRLF + ;
			"(G:\Departamentos\Sintegra ou \\SEUSERVIDOR\Departamentos\Sintegra) antes de selecionar o arquivo." + CRLF + CRLF + ;
			"Arquivo selecionado: " + cArqPrint, "Atencao")
		Return .F.
	EndIf

	lConfirmado := ApMsgYesNo( ;
		"Confirma que verificou a situacao cadastral da IE no print selecionado?" + CRLF + CRLF + ;
		"Arquivo: " + cArqPrint, ;
		"Confirmacao manual de IE")

	If lConfirmado
		AFIS022LOGMAN(cUF, cCNPJ, cCPF, cIE)

		//*** feedback visual pro usuario, reforcando que a confirmacao dele
		//*** ficou registrada (usuario + data/hora) - efeito de "isso fica
		//*** rastreado", alem do print em si ficar guardado na pasta de rede.
		MsgInfo("Confirmacao registrada." + CRLF + CRLF + ;
			"Usuario: " + AllTrim(cUserName) + CRLF + ;
			"Data/Hora: " + DToC(Date()) + " " + Time() + CRLF + ;
			"Arquivo: " + cArqPrint, ;
			"Confirmacao manual de IE")
	EndIf

	cArqPrint := ""  //*** referencia descartada aqui - o AFIS022 nao copia/grava o arquivo

Return lConfirmado

//===================================================================================
// Funcao     : AFIS022LOGMAN
// Objetivo   : Loga METADADOS da confirmacao manual (usuario, data/hora, UF,
//              CNPJ/CPF, IE) no console do AppServer - o print em si fica
//              guardado na pasta de rede Departamentos\Sintegra, nao aqui.
// Autor-Data : Fabio Dratcu - 27/08/2026
//===================================================================================
Static Function AFIS022LOGMAN(cUF, cCNPJ, cCPF, cIE)

	ConOut("AFIS022 - CONFIRMACAO MANUAL DE IE - Usuario: " + AllTrim(cUserName) + ;
		" - " + DToC(Date()) + " " + Time() + ;
		" - UF: " + cUF + " - CNPJ: " + cCNPJ + " - CPF: " + cCPF + " - IE: " + IIf(Empty(cIE),"ISENTO",cIE))

Return Nil

//===================================================================================
// Funcao     : AFIS022SOUNM
// Objetivo   : Remove qualquer caractere que nao seja digito (0-9) de uma string,
//              e remove zeros a esquerda do resultado.
//===================================================================================
Static Function AFIS022SOUNM(cValor)

	Local cRet := ""
	Local nI

	For nI := 1 To Len(cValor)
		If SubStr(cValor, nI, 1) $ "0123456789"
			cRet += SubStr(cValor, nI, 1)
		EndIf
	Next nI

	//*** remove zeros a esquerda
	While Len(cRet) > 1 .And. Left(cRet, 1) == "0"
		cRet := SubStr(cRet, 2)
	EndDo

Return cRet

//===================================================================================
// Funcao     : AFIS022ISREADY
//===================================================================================
Static Function AFIS022ISREADY(cURLTss)

	Local oWS      := Nil
	Local lRetorno := .F.

	cURLTss := AllTrim(cURLTss)

	While !Empty(cURLTss) .And. Right(cURLTss, 1) == "/"
		cURLTss := SubStr(cURLTss, 1, Len(cURLTss) - 1)
	EndDo

	If Empty(cURLTss)
		Return .F.
	EndIf

	oWS := WsSpedCfgNFe():New()

	If ValType(oWS) != "O"
		Return .F.
	EndIf

	oWS:cUserToken := "TOTVS"
	oWS:_URL       := cURLTss + "/SPEDCFGNFe.apw"

	Begin Sequence
		lRetorno := oWS:CFGCONNECT()
	Recover
		lRetorno := .F.
	End Sequence

Return lRetorno
