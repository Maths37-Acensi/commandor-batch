# Commandor

## Architecture générale

...

### Serveur Applicatif

Serveurs :

- srv-kanban-app2 (prod actuelle)
- blo-commandor (test, futur prod)

#### Variables d'environnement

- APACHE_HOME
- APP_HOME (C:\app)
- CATALINA_HOME
- JAVA_HOME
- LOG_HOME
- PHP_HOME
- SSL_HOME
- TEMP_HOME

#### Arborescence des fichiers

**%APP_HOME%** :

- apache (%APACHE_HOME%)
    - Installation Apache 2.4
    - Configuration sous **conf** :
        - httpd.conf
        - mime.types
        - extra/httpd-vhosts.conf
        - extra/httpd-proxy.conf
- commandorv1 (à mettre sous un dossier project ?)
    - Pour l'instant inutile
    - Le dossier %CATALINA_HOME%\webapps\jwas\work devrait se retrouver ici
- commandorv2 (à mettre sous un dossier project ?)
    - Fichiers spécifiques à commandor v2
    - Configuration sous **config**
    - Fichiers divers sous **data**
    - Script d'installation et sa configuration (commandorv2.exe et commandorv2.xml)
    - Exécutable java (.jar) versionné et son lien symbolique (pg-blois-commandor-sb.jar)
- java
    - Installation Java 21
    - jdk21 (%JAVA_HOME%)
- log (%LOG_HOME%)
    - Dossier racine où sont stockés les logs
    - Chaque techno / projet contient un sous dossier
- php (%PHP_HOME%)
    - Installation PHP 5.3.28
    - Conguration dans **php.ini**
- prime-to-commandor (à mettre sous un dossier project ?)
    - Fichiers spécifiques à prime-to-commandor
    - Configuration yaml
    - Exécutable java (.jar) versionné et son lien symbolique (prime-to-commandor.jar)
- services
    - 1 batch par service Windows + une librairie **common.bat**
    - Arguments disponibles :
        - install
        - stop
        - start
        - delete
- ssl (%SSL_HOME%)
    - Contient les différents certificats
- tmp (%TEMP_HOME%)
    - Dossier pour les fichiers temporaires
- tomcat (%CATALINA_HOME%)
    - Installation Tomcat 9.0.115
    - Configuration sous **conf**
        - catalina.policy
        - logging.properties
        - server.xml
    - Installation commandor v1 sous **%CATALINA_HOME%\webapps\jwas**
        - Configuration :
            - META-INF\context.xml
            - WEB-INF\web.xml (notamment le workDir qu'il faudrait déplacer)
            - WEB-INF\classes\log4j.properties
            - work\webtask.xml
            - work\source.xml (appelé par le webtask.xml)
        - Exécutable java (.jar)
            - WEB-INF\lib\pg-kanban-1.5.2.jar
            - WEB-INF\lib\* (dépendances)
        - Fichiers divers sous **work**
- www
    - Dossier racine pour Apache (configuration dans le httpd.conf)
    - Contient la partie front des applications
    - 1 dossier par application (commandor1 et commandor2)
- service-manager.bat
    - Gestionnaire des services Windows des différentes applications, arguments possibles :
        - install : création
        - stop : arrêt
        - start : démarrage
        - delete : suppression

### Serveur SQL

Serveurs :

- blo-sql-prod01
    - Production
    - Instance commandor, port 1433
- blo-sql-test
    - Test
    - Instance commandor_test, port 1433

Bases de données :

- pg_commandorv1
    - Base de données pour commandor v1
- pg_commandorv1_rtcis
    - Base de données pour commandor v1 spécifique à RTCIS (obsolète avec Prime)
- pg_commandorv2
    - Base de données pour commandor v2
- pg_commandorv2_logs
    - Base de données pour commandor v2 spécifique aux logs
- pg_rtcis
    - Base de données pour commandor v2 spécifique à RTCIS (obsolète avec Prime)
- prime_data
    - Base de données spécifique à Prime (partira en production avec Prime)

## Configuration des mails

La configuration pour les mails se trouve à différents endroits :

- Fichier de configuration des applications
- Tables
    - [pg_commandorv1].[dbo].[sys_mail_notif] : champ value
    - [pg_commandorv1].[dbo].[SECU_UTILISATEUR] : champ mail
    - [pg_commandorv2].[dbo].[User] : champ email

## Gestion des habilitations

Les habilitations sont renseignées dans les tables.

### Commandor V1

La table concernée est la table **SECU_UTILISATEUR**, l'identifiant du profil se retrouve dans la table **SECU_PROFIL**.

Exemple de requête d'insertion des droits admin :

``` SQL
INSERT INTO secu_utilisateur (
    id_profil, 
    nom, 
    prenom,
    code,
    mail,
    modeAuthentification,
    desactivation,
    notifAlert
)
VALUES (
    (SELECT id FROM secu_profil WHERE nom = 'Administrateur'), 
    'Lutz', 
    'Fabien', 
    'lutz.fl', 
    'lutz.fl@pg.com', 
    'LDAP', 
    0, 
    1
);
```

### Commandor V2

La table concernée est la table User_Role, associée à la table **User** et la table **Role**.
Attention !
Il est important d'ajouter également le rôle PG au rôle admin, sinon la page *Etat des navettes* semble se charger à
l'infini (sans message d'erreur).

Exemple de requête d'insertion des droits admin et PG  :

``` SQL
-- Création de l'utilisateur
INSERT INTO [user] (
    email, 
    enabled, 
    firstname, 
    lastname, 
    locked, 
    username
)
VALUES (
    'pg@acensi.fr', 
    1, 
    'Fabien', 
    'Lutz', 
    0, 
    'lutz.fl'
);

-- Rôle admin
INSERT INTO user_role (
    user_id, 
    roles_id
) 
VALUES (
    (SELECT id FROM [user] WHERE username = 'lutz.fl'), 
    (SELECT id FROM role WHERE name = 'Administrateur')
), (
    (SELECT id FROM [user] WHERE username = 'lutz.fl'), 
    (SELECT id FROM role WHERE name = 'PG')
);
```

## Synchronisation des compteurs

### Commandor V1

1. Un robot appel via FTTM la procédure **pg_commandorv1.dbo.update_prod_en_cours**.
2. La procédure (suivant les paramètres renseignées) va mettre à jour la table **pg_commandorv1.dbo.ligne_sap**.
    1. @trigPlc int
    2. @codeLigne varchar(5)
    3. @numPo varchar(20)
    4. @qte varchar(20)
3. Cette mise à jour (sur un changement de **poPacking** ou **qteFlacon**) déclenche le trigger **trig_ligne_sap**.
4. Exécution de la procédure **pg_commandorv1.dbo.NotifySrvApp** par ce trigger
    1. event : 'LIGNE_SAP'
    2. eventData : '2,14,' (Liste des id lignes modifiées)
5. Exécution de la procédure **pg_commandorv1.dbo.usp_AsyncExecInvoke**
    1. procedureName : 'HTTP_Request'
    2. p1 : 'http://{app server url hardcode}/jwas/jwservlet13?task=WTDbNotif&xml=&lt;question&gt;&lt;q
       methode="
       notifyDbChanged" event="LIGNE_SAP" data="2,14,"/&gt;&lt;/question&gt;' (url d'appel à la servlet)
    3. n1 : '@sUrl'
    4. token : @token output
6. Appel du service SQL Server **pg_commandorv1.dbo.AsyncExecService**
   Attention ce service nécessite l'activation de OLE ainsi que du Broker Service SQL Server :

``` SQL
	 sp_configure 'show advanced options', 1
	 GO 
	 RECONFIGURE;
	 GO
	 sp_configure 'Ole Automation Procedures', 1
	 GO 
	 RECONFIGURE;
	 GO
	 DECLARE @return_value INT
     EXEC @return_value = init_database @trig = 1
     SELECT 'Return Value' = @return_value
     GO
```

7. Ajout du call à la queue **pg_commandorv1.dbo.AsyncExecQueue**
8. Exécution de la procédure **pg_commandorv1.dbo.usp_AsyncExecActivated**
9. Exécution de la procédure **pg_commandorv1.dbo.usp_procedureInvokeHelper** qui semble faire l'appel final à la
   servlet

### Commandor V2

Prérequis : mise à jour de **pg_commandorv1.dbo.ligne_sap** qu'il utilise.

1. Job SQL Server **TLG_syncOldCommandorNewCommandor**
    - Chaque 30s, exécution de la procédure **pg_commandorv2.dbo.synchroCompteurs** sans paramètres
2. Trace dans la table **pg_commandorv2_logs.dbo.log_application** et mise à jour de la table *
   *pg_commandorv2.dbo.PoPacking**

## Commandor V1

TODO

## Commandor V2

TODO

## Prime To Commandor

TODO

## TODO List

- Certificats
- Connexion à Prime Connector impossible depuis blo-commandor
- Version SQL Server différente entre les environnements :
    - Production (blo-sql-prod01) : 15.0.2116.2
    - Test (blo-sql-test) : 17.0.1000.7
    - Impact à minima sur la synchronisation des compteurs
        - pg_commandorv1.dbo.NotifySrvApp : Encodage de l'url à faire manuellement
        - pg_commandorv1.dbo.HTTP_Request : Changement du **Content-Type** pour **application/plain-text**
- URL prime replicat à harmoniser

## Notes

J'ai ajouté le certicat Root présent sous C:\domaine\Certificat dans le cacerts du jdk (keytool -importcert -file "PG
Root CA 2.cer" -cacerts -alias pg-root-ca).