/* ============================================================================
   DrSanté — mesures biologiques et fiches d'observation
   ----------------------------------------------------------------------------
   Requêtes EN LECTURE SEULE, exécutées dans SSMS sur le serveur (base DrSante)
   le 13/09/2026. Aucune ne modifie la base. Aucune n'affiche de donnée patient :
   celles qui passent par PATIENT_MEASURE ne renvoient que des totaux par mesure.

   Pour chaque requête : ce qu'elle cherche, et ce qu'elle a montré ce jour-là.
   ========================================================================== */

USE DrSante;


/* --- 1. Le dictionnaire des mesures -------------------------------------- */
/*  dbo.MAGNITUDE (« Grandeur » dans l'interface et chez OAK Consult).
    Suppression douce : DeletionDate renseignée = mesure supprimée.
    Exemple de résultat : 648 lignes, 476 actives.                                    */

SELECT COUNT(*) AS total,
       SUM(CASE WHEN DeletionDate IS NULL THEN 1 ELSE 0 END) AS actives
FROM dbo.MAGNITUDE;


/* --- 2. Mesures actives, avec leur usage réel ---------------------------- */
/*  Une ligne par mesure (par identifiant : ne pas utiliser DISTINCT sur le
    nom, SQL ne distinguant pas les majuscules, « CRP mg/l » et « CRP mg/L »
    seraient fusionnés à tort).
    Exemple de résultat : tous les résultats sont rattachés à une mesure active (voir
    requête 2 bis) — la fusion SQL faite par Grégory au printemps 2026 a bien
    emporté l'historique.
    Collable tel quel dans l'éditeur : « Coller la liste de la base… ».      */

SELECT m.Name AS nom,
       ISNULL(m.Unit, '') AS unite,
       COUNT(pm.Id) AS utilisations,
       SUM(CASE WHEN pm.[Date] >= DATEADD(month, -12, GETDATE()) THEN 1 ELSE 0 END) AS sur_12_mois,
       CONVERT(varchar(10), MAX(pm.[Date]), 23) AS derniere
FROM dbo.MAGNITUDE m
LEFT JOIN dbo.PATIENT_MEASURE pm
       ON pm.MagnitudeId = m.Id AND pm.DeletionDate IS NULL
WHERE m.DeletionDate IS NULL AND m.Name IS NOT NULL AND m.Name <> ''
GROUP BY m.Id, m.Name, m.Unit
ORDER BY utilisations DESC, nom;


/* --- 2 bis. Les résultats sont-ils tous rattachés à une mesure active ? -- */
/*  Totaux seulement, aucune donnée patient.
    Exemple de résultat : une seule ligne — « mesure active », N résultats,
    du 2025-04-26 au 2026-09-11. Aucun résultat sur une mesure supprimée
    ni introuvable.                                                           */

SELECT CASE WHEN m.Id IS NULL THEN 'mesure introuvable'
            WHEN m.DeletionDate IS NULL THEN 'mesure active'
            ELSE 'mesure supprimée' END AS rattachement,
       COUNT(*) AS resultats,
       CONVERT(varchar(10), MIN(pm.[Date]), 23) AS premier,
       CONVERT(varchar(10), MAX(pm.[Date]), 23) AS dernier
FROM dbo.PATIENT_MEASURE pm
LEFT JOIN dbo.MAGNITUDE m ON m.Id = pm.MagnitudeId
WHERE pm.DeletionDate IS NULL
GROUP BY CASE WHEN m.Id IS NULL THEN 'mesure introuvable'
              WHEN m.DeletionDate IS NULL THEN 'mesure active'
              ELSE 'mesure supprimée' END;


/* --- 3. Qui référence une mesure par son identifiant ? ------------------- */
/*  Exemple de résultat : seulement PATIENT_MEASURE (les résultats), MEASURE_TEMPLATE et
    EXAM_RECEIVED_MAGNITUDE_MATCHING (correspondance des résultats labo).
    Les fiches d'observation N'EN FONT PAS PARTIE.                           */

SELECT OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id) AS table_source,
       COL_NAME(fk.parent_object_id, fk.parent_column_id) AS colonne
FROM sys.foreign_key_columns fk
WHERE fk.referenced_object_id = OBJECT_ID('dbo.MAGNITUDE');


/* --- 4. Comment une fiche stocke ses champs ------------------------------ */
/*  Exemple de résultat : dbo.OBSERVATION_FORMAT_FIELD n'a aucune colonne d'identifiant
    de mesure. La mesure est dans Comment, en texte : « nom|unité ».
    La table a aussi DefaultValue, MandatoryField, VisibleField et
    FormulaAppendix, absents des fichiers XML exportés.                      */

SELECT c.name AS colonne, TYPE_NAME(c.user_type_id) AS type
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('dbo.OBSERVATION_FORMAT_FIELD')
ORDER BY c.column_id;


/* --- 5. Contrôle de tous les champs mesure de toutes les fiches ---------- */
/*  Compare le texte de chaque champ mesure aux mesures actives.
    Le type « mesure » est retrouvé grâce à un champ connu (« HbA1c|% »).
    Exemple de résultat : 25 champs dans 2 fiches actives (« Consultation » et « Fiche
    d'observation Généraliste v2 ») — 9 ABSENTE, 4 casse/accents, 12 exacte.
    Effet réel d'un nom qui ne correspond plus : à confirmer en consultation
    (une case créatinine vide alors que le résultat existe).                  */

WITH champs_mesure AS (
  SELECT f.Label AS formulaire, ff.Name AS champ, ff.Comment AS mesure
  FROM dbo.OBSERVATION_FORMAT_FIELD ff
  JOIN dbo.OBSERVATION_FORMAT f ON f.Id = ff.FormatId
  WHERE f.DeletionDate IS NULL
    AND ff.Type IN (SELECT DISTINCT Type FROM dbo.OBSERVATION_FORMAT_FIELD WHERE Comment = 'HbA1c|%')
)
SELECT c.formulaire, c.champ, c.mesure,
  CASE
    WHEN EXISTS (SELECT 1 FROM dbo.MAGNITUDE m WHERE m.DeletionDate IS NULL
                 AND (m.Name + '|' + ISNULL(m.Unit, '')) COLLATE Latin1_General_CS_AS = c.mesure COLLATE Latin1_General_CS_AS)
      THEN 'exacte'
    WHEN EXISTS (SELECT 1 FROM dbo.MAGNITUDE m WHERE m.DeletionDate IS NULL
                 AND (m.Name + '|' + ISNULL(m.Unit, '')) COLLATE Latin1_General_CI_AI = c.mesure COLLATE Latin1_General_CI_AI)
      THEN 'casse ou accents differents'
    ELSE 'ABSENTE'
  END AS statut
FROM champs_mesure c
ORDER BY statut, formulaire, champ;


/* --- 6. À refaire APRÈS chaque fusion ou renommage de mesures ------------ */
/*  Ce que révèle l'outil Grandeur Wizard (OAK Consult, 2021) : une fusion
    réécrit le nom des résultats patients et supprime la mesure fusionnée,
    mais ne touche PAS aux fiches d'observation, et ne convertit PAS les
    unités. Donc après chaque fusion :
      - relancer la requête 5 pour repérer les fiches devenues « ABSENTE » ;
      - vérifier qu'aucune fusion n'a mélangé deux unités différentes.        */
