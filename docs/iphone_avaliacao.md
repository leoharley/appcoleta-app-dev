# iPhone: navegador ou aplicativo da App Store? (Prompt 7)

**Status:** avaliação técnica escrita. **Falta reproduzir as falhas num iPhone real**, que é o primeiro passo do prompt e não pôde ser feito aqui.

## O que o iPhone permite no navegador (Safari, app adicionado à tela de início)

| Necessidade | No navegador | Consequência |
|---|---|---|
| Gravar áudio | Funciona com a tela ligada (o app grava em mp4/aac no Safari) | Ok com a tela aberta |
| Gravar com a tela bloqueada | **Não.** O Safari pausa a página e o microfone quando a tela apaga ou o app sai da frente | A gravação para; o app avisa e oferece gravar de novo, mas o trecho se perde |
| GPS | Funciona com a página aberta; pede permissão de novo com frequência | Ok, com mais toques |
| Sem sinal | Funciona, mas o iOS pode **apagar os dados do site** se o app ficar alguns dias sem uso fora da tela de início | Risco de perder entrevistas guardadas |
| Espaço para áudio e foto | Limitado e controlado pelo sistema | Risco em dias longos sem sinal |

## Recomendação

Para entrevistas com áudio do início ao fim e coleta sem sinal, o iPhone precisa do **aplicativo instalado pela App Store**, gerado a partir do mesmo código Flutter. O navegador serve só para uso eventual, com a tela sempre ligada.

## O que já está pronto no código

- Identificação do app `br.com.institutoalveslima.coleta` e textos de permissão: microfone, câmera, localização e galeria.
- Modo de áudio em segundo plano (`UIBackgroundModes: audio`) no `ios/Runner/Info.plist`, para a gravação continuar com a tela bloqueada no app nativo.
- Avisos na tela quando a gravação falha ou para (Prompt 6).

## Próximos passos

1. Num Mac com Xcode: `flutter build ipa`, com a conta Apple Developer do instituto.
2. Enviar para o TestFlight e instalar nos iPhones da equipe.
3. Rodar o roteiro de teste do documento no iPhone. Prestar atenção em: tela bloqueada durante a gravação, modo avião, fechar e reabrir no meio da entrevista, negar as permissões.
4. Registrar aqui o resultado de cada item.
