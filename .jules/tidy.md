## 2026-06-22 : Fix empty Mix Ideal logic and Null constraint
**Aprendizado:** Applying the mix ideal logic over an empty database table caused the AI to hallucinate responses since there were no results to cross-reference. In addition, when inserting the static list, a `cod_categoria` string representation of an ID was necessary because of a not-null constraint.
**Ação:** Seeded the database with initial mix ideal data and properly rebuilt all dependent RPC functions via the MCP API successfully on the EVOLUÇÃO ANUAL project.
