---
name: review
description: Revisão independente do trabalho feito (diff atual ou arquivos indicados) contra as regras do projeto, com veredito (/review [arquivos]).
---
Delegue ao subagente `reviewer` passando `$ARGUMENTS` (ou "git diff" se vazio). Mostre o veredito completo.
Se houver bloqueadores, ofereça corrigir delegando ao agente responsável e repetir a revisão.
