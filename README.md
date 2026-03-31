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

#### Références

1. update_prod_en_cours

    ``` SQL
    CREATE PROCEDURE [dbo].[update_prod_en_cours](
        @trigPlc int, 
        @codeLigne varchar(5), 
        @numPo varchar(20), 
        @qte varchar(20)
    )
    as
    begin
        
        begin transaction;
        begin try
            
            -- Déclaration des variables
            declare @msg varchar(max),
            @txtParams varchar(max),
            @idLigne int,
            @lastPo varchar(20),
            @lastQte int;
            
            set @msg = N'--- Début d''éxécution de la procédure ---';
            set @txtParams = N'update_prod_en_cours('+
            'codeLigne = '+@codeLigne+
            ', numPo = '+@numPo+
            ', qte = '+@qte+
            ')';
            
            exec log N'DEBUG', N'FTTM', N'update_prod_en_cours', @msg, @txtParams
            
            -- Récupération de l'ID ligne
            select @idLigne = id
            from LIGNE_SAP
            where codeSAP = @codeLigne;
    
            if @idLigne is null
            begin
                set @msg = N'Ligne (Code : '+@codeLigne+') introuvable dans la base de données !';
                exec log N'ERROR', N'FTTM', N'update_prod_en_cours',@msg , @txtParams
                RAISERROR('Erreur : %s',15,1, @msg);
            end
            
            exec log N'DEBUG', N'FTTM', N'update_prod_en_cours', N'Mise à jour de la table LIGNE_SAP', @txtParams
            
            select @lastPo=poPacking, @lastQte=qteFlacon
            from LIGNE_SAP
            where id = @idLigne;
            
            if (@lastPo is null) or (@lastQte is null) or (@numPo != @lastPo) or (@qte != @lastQte)
            begin
                update LIGNE_SAP 
                set poPacking=@numPo,
                    qteFlacon=@qte,
                    horodate=CURRENT_TIMESTAMP
                where id = @idLigne;
            end
            else
            begin
                update LIGNE_SAP 
                set horodate=CURRENT_TIMESTAMP
                where id = @idLigne;
            end
            
            exec log N'DEBUG', N'FTTM', N'update_prod_en_cours', N'Mise à jour de la table LIGNE_PROD_EN_COURS_HISTO', @txtParams
            
            insert into LIGNE_PROD_EN_COURS_HISTO (idLigneSap, poPacking, qteFlacon, horodate)
            values (@idLigne, @numPo, @qte,CURRENT_TIMESTAMP);
            
            exec log N'DEBUG', N'FTTM', N'update_prod_en_cours', N'--- Fin d''éxécution de la procédure ---', @txtParams
            commit transaction;
    
            -- Return trigger
            return @trigPlc;
            
        end try
        begin catch
            
            declare @message varchar(max);
            select @message = ERROR_MESSAGE();
            
            rollback transaction;
            
            exec log N'ERROR', N'FTTM', N'update_prod_en_cours', @message, @txtParams
            --raiserror (@message, 15, 1) ;
            
            -- Return trigger
            return @trigPlc;
            
        end catch;
    end
    ```

2. trig_ligne_sap

    ``` SQL
    CREATE TRIGGER [trig_ligne_sap] 
       ON  LIGNE_SAP
       AFTER INSERT,UPDATE
    AS
    BEGIN
    SET NOCOUNT ON;
    
        --------------- Notification SrvApp ---------------
        DECLARE @data VARCHAR(MAX)
        DECLARE @idLigne VARCHAR(10)
        DECLARE curs CURSOR
        FOR
            SELECT id
            FROM INSERTED
            
        IF @@error <> 0 GOTO LBL_ERROR
        
        OPEN curs
        FETCH curs INTO @idLigne
        
        SET @data = ''
        WHILE @@fetch_Status = 0
        BEGIN
           SET @data = @data + @idLigne + ','
           FETCH curs INTO @idLigne
        END
    
        CLOSE curs
        DEALLOCATE curs
    
        IF UPDATE(poPacking) OR UPDATE(qteFlacon)
        begin
            EXEC NotifySrvApp 'LIGNE_SAP', @data
        end
        
        RETURN
    
        -- rollback en cas d'erreur
    LBL_ERROR:
    ROLLBACK TRANSACTION
    END
    ```

3. NotifySrvApp

    ``` SQL
    CREATE procedure [dbo].[NotifySrvApp]( @event varchar(100), @eventData varchar(1000))
    As
    declare @url varchar(1000),
    @token uniqueidentifier;
    
        Set @url = 'http://10.201.0.253/jwas/jwservlet13?task=WTDbNotif&xml=' +
                   '<question><q methode="notifyDbChanged" event="' + @event + '" data="' + @eventData + '"/></question>'
                   
        exec usp_AsyncExecInvoke @procedureName = N'HTTP_Request'
         , @p1 = @url, @n1 = N'@sUrl'
         , @token = @token output;
    
        /****************************************************
         ********************* ATTENTION ********************
         ********** NE PAS OUBLIER D'AUTORISER OLE **********
         ****************************************************
         ** https://sqlsolace.blogspot.com/2009/09/sql-server-blocked-access-to-procedure.html
         **
         ** sp_configure 'show advanced options', 1
         ** GO 
         ** RECONFIGURE;
         ** GO
         ** sp_configure 'Ole Automation Procedures', 1
         ** GO 
         ** RECONFIGURE;
         ** GO 
         ** sp_configure 'show advanced options', 1
         ** GO 
         ** RECONFIGURE;
         ****************************************************/
    ```

4. usp_AsyncExecInvoke

    ``` SQL
    create procedure [usp_AsyncExecInvoke]
    @procedureName sysname
    , @p1 sql_variant = NULL, @n1 sysname = NULL
    , @p2 sql_variant = NULL, @n2 sysname = NULL
    , @p3 sql_variant = NULL, @n3 sysname = NULL
    , @p4 sql_variant = NULL, @n4 sysname = NULL
    , @p5 sql_variant = NULL, @n5 sysname = NULL
    , @token uniqueidentifier output
    as
    begin
    declare @h uniqueidentifier
    , @xmlBody xml
    , @trancount int;
    set nocount on;
    
    set @trancount = @@trancount;
    if @trancount = 0
    begin transaction
    else
    save transaction usp_AsyncExecInvoke;
    begin try
    begin dialog conversation @h
    from service [AsyncExecService]
    to service N'AsyncExecService', 'current database'
    with encryption = off;
    select @token = [conversation_id]
    from sys.conversation_endpoints
    where [conversation_handle] = @h;
    
            select @xmlBody = (
                select @procedureName as [name]
                , (select * from (
                    select [dbo].[fn_DescribeSqlVariant] (@p1, @n1) AS [*] 
                        WHERE @p1 IS NOT NULL
                    union all select [dbo].[fn_DescribeSqlVariant] (@p2, @n2) AS [*] 
                        WHERE @p2 IS NOT NULL
                    union all select [dbo].[fn_DescribeSqlVariant] (@p3, @n3) AS [*] 
                        WHERE @p3 IS NOT NULL
                    union all select [dbo].[fn_DescribeSqlVariant] (@p4, @n4) AS [*] 
                        WHERE @p4 IS NOT NULL
                    union all select [dbo].[fn_DescribeSqlVariant] (@p5, @n5) AS [*] 
                        WHERE @p5 IS NOT NULL
                    ) as p for xml path(''), type
                ) as [parameters]
                for xml path('procedure'), type);
            send on conversation @h (@xmlBody);
            /*insert into [AsyncExecResults]
                ([token], [submit_time])
                values
                (@token, getutcdate());*/
        if @trancount = 0
            commit;
        end try
        begin catch
            declare @error int
                , @message nvarchar(2048)
                , @xactState smallint;
            select @error = ERROR_NUMBER()
                , @message = ERROR_MESSAGE()
                , @xactState = XACT_STATE();
            if @xactState = -1
                rollback;
            if @xactState = 1 and @trancount = 0
                rollback
            if @xactState = 1 and @trancount > 0
                rollback transaction usp_my_procedure_name;
    
            raiserror(N'Error: %i, %s', 16, 1, @error, @message);
        end catch
    end
    ```

5. init_database

    ``` SQL
    CREATE procedure init_database( @trig int)
    As
    
    begin
    
        declare @dbname varchar(100);
        set @dbname=(db_name());
    
        IF((SELECT is_broker_enabled FROM sys.databases WHERE name = @dbname) = 0)
        begin
            exec('alter database '+@dbname+' set new_broker with rollback immediate');	
            exec('alter database '+@dbname+' set enable_broker with rollback immediate');	
            
            IF((SELECT is_broker_enabled FROM sys.databases WHERE name = @dbname) = 0)
            begin
                Raiserror('Erreur lors de l''activation du service broker !', 16, 1)
            end
        end
        
        return @trig;
    end
    ```

6. usp_AsyncExecActivated

    ``` SQL
    create procedure usp_AsyncExecActivated
    as
    begin
    set nocount on;
    declare @h uniqueidentifier
    , @messageTypeName sysname
    , @messageBody varbinary(max)
    , @xmlBody xml
    , @startTime datetime
    , @finishTime datetime
    , @execErrorNumber int
    , @execErrorMessage nvarchar(2048)
    , @xactState smallint
    , @token uniqueidentifier;
    
        begin transaction;
        begin try;
            receive top(1)
                @h = [conversation_handle]
                , @messageTypeName = [message_type_name]
                , @messageBody = [message_body]
                from [AsyncExecQueue];
            if (@h is not null)
            begin
                if (@messageTypeName = N'DEFAULT')
                begin
                    -- The DEFAULT message type is a procedure invocation.
                    --
                    select @xmlBody = CAST(@messageBody as xml);
    
                    save transaction usp_AsyncExec_procedure;
                    select @startTime = GETUTCDATE();
                    begin try
                        exec [usp_procedureInvokeHelper] @xmlBody;
                    end try
                    begin catch
                    -- This catch block tries to deal with failures of the procedure execution
                    -- If possible it rolls back to the savepoint created earlier, allowing
                    -- the activated procedure to continue. If the executed procedure
                    -- raises an error with severity 16 or higher, it will doom the transaction
                    -- and thus rollback the RECEIVE. Such case will be a poison message,
                    -- resulting in the queue disabling.
                    --
                    select @execErrorNumber = ERROR_NUMBER(),
                        @execErrorMessage = ERROR_MESSAGE(),
                        @xactState = XACT_STATE();
                    if (@xactState = -1)
                    begin
                        rollback;
                        raiserror(N'Unrecoverable error in procedure: %i: %s', 16, 10,
                            @execErrorNumber, @execErrorMessage);
                    end
                    else if (@xactState = 1)
                    begin
                        rollback transaction usp_AsyncExec_procedure;
                    end
                    end catch
    
                    select @finishTime = GETUTCDATE();
                    select @token = [conversation_id]
                        from sys.conversation_endpoints
                        where [conversation_handle] = @h;
                    if (@token is null)
                    begin
                        raiserror(N'Internal consistency error: conversation not found', 16, 20);
                    end
                    /*update [AsyncExecResults] set
                        [start_time] = @starttime
                        , [finish_time] = @finishTime
                        , [exec_ms] = DATEDIFF(millisecond,@starttime,@finishTime)
                        , [error_number] = @execErrorNumber
                        , [error_message] = @execErrorMessage
                        where [token] = @token;
                    if (0 = @@ROWCOUNT)
                    begin
                        raiserror(N'Internal consistency error: token not found', 16, 30);
                    end*/
                    end conversation @h;
                end
                else if (@messageTypeName = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
                begin
                    end conversation @h;
                end
                else if (@messageTypeName = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error')
                begin
                    declare @errorNumber int
                        , @errorMessage nvarchar(4000);
                    select @xmlBody = CAST(@messageBody as xml);
                    with xmlnamespaces (DEFAULT N'http://schemas.microsoft.com/SQL/ServiceBroker/Error')
                    select @errorNumber = @xmlBody.value ('(/Error/Code)[1]', 'INT'),
                        @errorMessage = @xmlBody.value ('(/Error/Description)[1]', 'NVARCHAR(4000)');
                    -- Update the request with the received error
                    select @token = [conversation_id] 
                        from sys.conversation_endpoints 
                        where [conversation_handle] = @h;
                    /*update [AsyncExecResults] set
                        [error_number] = @errorNumber
                        , [error_message] = @errorMessage
                        where [token] = @token;*/
                    end conversation @h;
                 end
               else
               begin
                    raiserror(N'Received unexpected message type: %s', 16, 50, @messageTypeName);
               end
            end
            commit;
        end try
        begin catch
            declare @error int
             , @message nvarchar(2048);
            select @error = ERROR_NUMBER()
                , @message = ERROR_MESSAGE()
                , @xactState = XACT_STATE();
            if (@xactState <> 0)
            begin
             rollback;
            end;
            raiserror(N'Error: %i, %s', 1, 60,  @error, @message) with log;
        end catch
    end
    ```

7. usp_procedureInvokeHelper

    ``` SQL
    create procedure [usp_procedureInvokeHelper] (@x xml)
    as
    begin
    set nocount on;
    
        declare @stmt nvarchar(max)
            , @stmtDeclarations nvarchar(max)
            , @stmtValues nvarchar(max)
            , @i int
            , @countParams int
            , @namedParams nvarchar(max)
            , @paramName sysname
            , @paramType sysname
            , @paramPrecision int
            , @paramScale int
            , @paramLength int
            , @paramTypeFull nvarchar(300)
            , @comma nchar(1)
    
        select @i = 0
            , @stmtDeclarations = N''
            , @stmtValues = N''
            , @namedParams = N''
            , @comma = N''
    
        declare crsParam cursor forward_only static read_only for
            select x.value(N'@Name', N'sysname')
                , x.value(N'@BaseType', N'sysname')
                , x.value(N'@Precision', N'int')
                , x.value(N'@Scale', N'int')
                , x.value(N'@MaxLength', N'int')
            from @x.nodes(N'//procedure/parameters/parameter') t(x);
        open crsParam;
    
        fetch next from crsParam into @paramName
            , @paramType
            , @paramPrecision
            , @paramScale
            , @paramLength;
        while (@@fetch_status = 0)
        begin
            select @i = @i + 1;
    
            select @paramTypeFull = @paramType +
                case
                when @paramType in (N'varchar'
                    , N'nvarchar'
                    , N'varbinary'
                    , N'char'
                    , N'nchar'
                    , N'binary') then
                    N'(' + cast(@paramLength as nvarchar(5)) + N')'
                when @paramType in (N'numeric') then
                    N'(' + cast(@paramPrecision as nvarchar(10)) + N',' +
                    cast(@paramScale as nvarchar(10))+ N')'
                else N''
                end;
    
            -- Some basic sanity check on the input XML
            if (@paramName is NULL
                or @paramType is NULL
                or @paramTypeFull is NULL
                or charindex(N'''', @paramName) > 0
                or charindex(N'''', @paramTypeFull) > 0)
                raiserror(N'Incorrect parameter attributes %i: %s:%s %i:%i:%i'
                    , 16, 10, @i, @paramName, @paramType
                    , @paramPrecision, @paramScale, @paramLength);
    
            select @stmtDeclarations = @stmtDeclarations + N'
    declare @pt' + cast(@i as varchar(3)) + N' ' + @paramTypeFull
    , @stmtValues = @stmtValues + N'
    select @pt' + cast(@i as varchar(3)) + N'=@x.value(
    N''(//procedure/parameters/parameter)[' + cast(@i as varchar(3))
    + N']'', N''' + @paramTypeFull + ''');'
    , @namedParams = @namedParams + @comma + @paramName
    + N'=@pt' + cast(@i as varchar(3));
    
            select @comma = N',';
    
            fetch next from crsParam into @paramName
                , @paramType
                , @paramPrecision
                , @paramScale
                , @paramLength;
        end
    
        close crsParam;
        deallocate crsParam;        
    
        select @stmt = @stmtDeclarations + @stmtValues + N'
    exec ' + quotename(@x.value(N'(//procedure/name)[1]', N'sysname'));
    
        if (@namedParams != N'')
            select @stmt = @stmt + N' ' + @namedParams;
    
        exec sp_executesql @stmt, N'@x xml', @x;
    end
    ```

8. log

    ``` SQL
    CREATE PROCEDURE log(@niveau varchar(10), @categorie varchar(50), @source varchar(1000), @message varchar(MAX), @info varchar(MAX))
    AS
    BEGIN
    --IF @niveau != 'DEBUG'
    INSERT INTO LOG_APPLICATION (horodate, categorie, source, niveau, message, trace) VALUES (CURRENT_TIMESTAMP, @categorie, @source, @niveau, @message, @info)
    END
    ```

### Commandor V2

Prérequis : mise à jour de **pg_commandorv1.dbo.ligne_sap** qu'il utilise.

1. Job SQL Server **TLG_syncOldCommandorNewCommandor**
2. Exécution de la procédure **pg_commandorv2.dbo.synchroCompteurs**
    - Fréquence : chaque 30s
    - Pas de paramètres
3. Synchronisation des compteurs :
    - Trace dans la table **pg_commandorv2_logs.dbo.log_application**
    - Exécution de la vue **pg_commandorv2.dbo.vLigneSapCommandorV1** qui fait référence à la table ligne_sap de
      commandor v1
    - Mise à jour de la table **pg_commandorv2.dbo.PoPacking**

#### Références

1. synchroCompteurs

    ``` SQL
    -- =============================================
    -- Author:		GBR. TLG Pro
    -- Create date: 2020-01-xx
    -- Description:	Synchronisation entre les compteurs lignes de la bdd [pg_kanban] et les tables de [pg_commandorv2]
    -- =============================================
    CREATE PROCEDURE [dbo].[synchroCompteurs]
    AS
    BEGIN
    
    DECLARE @idPo bigint
    DECLARE @idLigne bigint
    DECLARE @idComposant bigint
    DECLARE @idComposantType bigint
    
    DECLARE @numPO varchar(10)
    DECLARE @gcasCompo varchar(10)
    DECLARE @codeLigne varchar(10)
    
    -- ================================================================================================
    -- A.  Si on revient sur un PO que l'on a sauté auparavant c'est à dire que 
    --        1. c'est le run sur la ligne, 
    --        2. il a une date de fin,
    --        3. la quantité produite est = 0.
    -- Il faut remettre tout le RUN de ce PO à partir du run en cours */
    IF EXISTS ( 
      SELECT p.id 
      FROM PoPacking p
        INNER JOIN [Ligne] l ON p.idLigne=l.id
        INNER JOIN [pg_commandorv2].[dbo].[vLigneSapCommandorV1] ls ON ls.codeSAP = 'B' + l.code AND p.numPo LIKE '%'+ls.poPacking
      WHERE ls.qteFlacon>=0 
        AND len(ls.poPacking)>=8
        AND p.horoFinAPI IS NOT NULL
        AND p.quantiteProduite=0 
      )
    BEGIN 
    
      DECLARE @ordreRunEnCours int /* Rappel : ce numéro correspond au run que l'on reprend */
        
      /* infos sur le run qui vient de réapparaître */
      SELECT @idPo=pp.id, @idComposant=ppc.idComposant, @idLigne=l.id, @ordreRunEnCours=pp.ordre, @idComposantType = c.idComposantType 
        , @numPO=pp.numPo, @gcasCompo=c.gcas, @codeLigne=l.code
      FROM [PoPacking] pp
        INNER JOIN [PoPackingComposant] ppc ON ppc.idPoPacking = pp.id 
        INNER JOIN [Composant] c ON c.id = ppc.idComposant 
        INNER JOIN [Ligne] l ON pp.idLigne=l.id
        INNER JOIN [pg_commandorv2].[dbo].[vLigneSapCommandorV1] ls ON ls.codeSAP = 'B' + l.code AND pp.numPo LIKE '%'+ls.poPacking
      WHERE ls.qteFlacon >= 0 
        AND len(ls.poPacking)>=8
        AND pp.horoFinAPI IS NOT NULL
      
      
      INSERT INTO [pg_commandorv2_logs].[dbo].[log_application] ([horodate],[categorie],[niveau],[message],[source],[thread],[trace])
        VALUES (GetDate(),'syncCompteurs','INFO','PO. Retour PO','sp [synchroCompteurs]',null,
                 'Ligne:' + @codeLigne + 'PO: ' + @numPO + ' GCAS:' +  @gcasCompo 
            )
    
      DECLARE @ordreMaxPoFini int /* Le plus grand numéro d'ordre du dernier PO produit */
      SELECT @ordreMaxPoFini= max(ordre)
      FROM PoPacking pp 
      WHERE pp.idLigne = @idLigne
        AND pp.horoFinAPI IS NOT NULL
    
        DECLARE @ordreMinRun INT;
        DECLARE @ordreMaxRun INT;
     
        -- SGI et WMO le 08/01/2025 : Optimisation une requête unique pour min et max
        SELECT 
            @ordreMinRun = MIN(CASE WHEN pp.ordre > prev_run.max_ordre THEN pp.ordre END),
            @ordreMaxRun = MAX(CASE WHEN pp.ordre < next_run.min_ordre THEN pp.ordre END)
        FROM [PoPacking] pp
        INNER JOIN [PoPackingComposant] ppc ON pp.id = ppc.idPoPacking 
        INNER JOIN [Composant] c ON c.id = ppc.idComposant
        LEFT JOIN (
            SELECT MAX(pp.ordre) AS max_ordre
            FROM [PoPacking] pp 
            INNER JOIN [PoPackingComposant] ppc ON pp.id = ppc.idPoPacking 
            INNER JOIN [Composant] c ON c.id = ppc.idComposant 
            WHERE pp.idLigne = @idLigne 
            AND c.idComposantType = @idComposantType
            AND c.id <> @idComposant
            AND pp.ordre < @ordreRunEnCours
        ) prev_run ON 1 = 1
        LEFT JOIN (
            SELECT MIN(pp.ordre) AS min_ordre
            FROM [PoPacking] pp 
            INNER JOIN [PoPackingComposant] ppc ON pp.id = ppc.idPoPacking 
            INNER JOIN [Composant] c ON c.id = ppc.idComposant 
            WHERE pp.idLigne = @idLigne
            AND c.idComposantType = @idComposantType
            AND c.id <> @idComposant
            AND pp.ordre > @ordreRunEnCours
        ) next_run ON 1 = 1
        WHERE pp.idLigne = @idLigne 
        AND c.id = @idComposant
    
    -- SGI et WMO le 08/01/2025 : Ancien code avant optimisation de la requête unique pour min et max
    /*  
    
      DECLARE @ordreMinRun int  /* Le premier du run dans l'ordre des PO du PO en cours */
      SELECT @ordreMinRun = min(pp.ordre)
      FROM [PoPacking] pp 
        INNER JOIN [PoPackingComposant] ppc ON pp.id=ppc.idPoPacking 
        INNER JOIN [Composant] c ON c.id = ppc.idComposant 
      WHERE pp.idLigne = @idLigne 
        AND c.id = @idComposant
        AND pp.ordre > (
          
          SELECT max(pp.ordre) /* Le plus grand ordre avant le run du Po en cours (= dernier du run précédent) */
          FROM [PoPacking] pp 
            INNER JOIN [PoPackingComposant] ppc ON pp.id=ppc.idPoPacking 
            INNER JOIN [Composant] c ON c.id = ppc.idComposant 
          WHERE pp.idLigne = @idLigne 
            AND c.idComposantType = @idComposantType
            AND c.id <> @idComposant
            AND pp.ordre < @ordreRunEnCours
        )
        
      DECLARE @ordreMaxRun int /* Le dernier du run dans l'ordre des PO du PO en cours */
      SELECT @ordreMaxRun = max(pp.ordre)
      FROM [PoPacking] pp 
        INNER JOIN [PoPackingComposant] ppc ON pp.id=ppc.idPoPacking 
        INNER JOIN [Composant] c ON c.id = ppc.idComposant 
      WHERE pp.idLigne = @idLigne 
        AND c.id = @idComposant
        AND pp.ordre < (
          
          SELECT min(pp.ordre) /* Le plus petit ordre après le run du Po en cours (= premier du run suivant)*/
          FROM [PoPacking] pp 
            INNER JOIN [PoPackingComposant] ppc ON pp.id=ppc.idPoPacking 
            INNER JOIN [Composant] c ON c.id = ppc.idComposant 
          WHERE pp.idLigne = @idLigne
            AND c.idComposantType = @idComposantType
            AND c.id <> @idComposant
            AND pp.ordre > @ordreRunEnCours
        )
    */
    
          /*
      
      print CONCAT('idPo=', @idPo 
        , ', idComposant=', @idComposant 
        , ', idLigne=', @idLigne  
        , ', idComposantType=', @idComposantType 
        , ', ordreRunEnCours=', @ordreRunEnCours 
        , ', ordreMaxPoFini=', @ordreMaxRun 
        , ', ordreMaxRun=', @ordreMaxRun 
        , ', ordreMinRun=', @ordreMinRun)*/
          
      IF (@ordreMinRun IS NOT NULL AND @ordreMaxRun IS NOT NULL)
      BEGIN 
      
        INSERT INTO [pg_commandorv2_logs].[dbo].[log_application] ([horodate],[categorie],[niveau],[message],[source],[thread],[trace])
        VALUES (GetDate(),'syncCompteurs','INFO','PO. Retour PO. Déplacement PO','sp [synchroCompteurs]',null,
                 'Ligne:' + @codeLigne + ' PO: ' + @numPO + ' GCAS:' +  @gcasCompo 
                 + ' ordreMin:' + CAST(@ordreMinRun as varchar(8))
                 + ' ordreMax:' + CAST(@ordreMaxRun as varchar(8))
                 + ' delta:' + CAST((@ordreMaxRun-@ordreMinRun) as varchar(8))
            )
    
          SELECT *
          FROM PoPacking
          WHERE ordre BETWEEN @ordreMinRun AND @ordreMaxRun
          AND idLigne = @idLigne
          
          /* On décale l'ordre de tous les POs non commencés pour pouvoir insérer le "nouveau" run */
          UPDATE PoPacking 
          SET ordre = ordre + (@ordreMaxRun - @ordreMinRun) + 4 /* 3 parce qu'il va y avoir le run en cours et les PO du même run avant et ceux d'après, avec un trou (le Po en cours) */
          WHERE idLigne = @idLigne 
            AND horoDebAPI IS NULL
            AND id <> @idPo
            AND quantiteProduite = 0 
            
          /* On décale le "nouveau" run en cours */
          UPDATE PoPacking 
          SET ordre = @ordreMaxPoFini + 2, horoDebAPI = null, horoFinAPI = null /* +2 pour assurer une marge de sécurité si le Po précédent n'est toujours pas enregistré comme fini */
          WHERE id = @idPo
            AND quantiteProduite = 0 
          
          /* On décale les autres PO du run en cours, sachant que le PO en cours a déjà été décalé ce qui provoquera un trou dans l'ordre (pas grave) */
          UPDATE PoPacking 
          SET ordre = @ordreMaxPoFini + 3 + ordre - @ordreMinRun, horoDebAPI = null, horoFinAPI = null
          WHERE id <> @idPo 
            AND quantiteProduite = 0 
            AND ordre BETWEEN @ordreMinRun AND @ordreMaxRun
            
          SELECT top 250 *
          FROM PoPacking
          WHERE idLigne = @idLigne
          ORDER BY ordre desc
          
      END
      
    END
    
    -- ================================================================================================
    -- B. Nouveau PO en cours sur ligne => si  date déb nulle alors on met la date du compteur ligne (c'est à dire "vient de commencer")
    UPDATE p
    SET	horoDebAPI=ls.horodate, quantiteProduite=ls.qteFlacon
    FROM PoPacking p
        INNER JOIN [Ligne] l ON p.idLigne=l.id
        INNER JOIN [pg_commandorv2].[dbo].[vLigneSapCommandorV1] ls ON ls.codeSAP = 'B' + l.code
          AND ls.poPacking <> ''
          AND p.numPo LIKE '%'+ls.poPacking
    WHERE 
        ls.qteFlacon>=0 
        AND len(ls.poPacking)>=8
        AND p.horoDebAPI IS NULL -- pas déjà démarré
        
    -- ================================================================================================
    -- C. Boucle pour mettre des dates de fin aux PO passés qui n'en n'ont pas encore.
    DECLARE @idLignePrec int;
    DECLARE @horoDebAPI datetime;
    DECLARE @horoFinAPI datetime;
    DECLARE @previousHoroDebAPI datetime;
    
    -- ================================================================================================
    -- C1. curseur pour lister les Po
    DECLARE popacking_cursor CURSOR FOR 
        SELECT pp.idLigne, pp.id , pp.horoDebAPI , pp.horoFinAPI 
        FROM PoPacking pp 
        WHERE pp.horoDebAPI IS NOT NULL 
          AND pp.horoFinAPI IS NULL 
        ORDER BY idLigne, ordre DESC; -- par ligne, on va du plus récent au plus ancien (= on remonte le temps)
    
    OPEN popacking_cursor;
    FETCH NEXT FROM popacking_cursor INTO @idLigne, @idPo, @horoDebAPI , @horoFinAPI ;
    
    SET @idLignePrec=-1;
    
    -- ================================================================================================
    -- C2. Boucle
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @idLignePrec=@idLigne -- on est au moins sur le 2e enreg de la ligne => on met une date de fin (celle du début du PO qui a commencé après)
        BEGIN
            --PRINT @idPo;
            UPDATE PoPacking SET horoFinAPI=@previousHoroDebAPI WHERE id=@idPo
        END
        
        SET @idLignePrec=@idLigne;
        SET @previousHoroDebAPI=@horoDebAPI;
        -- enreg suivant
        FETCH NEXT FROM popacking_cursor INTO @idLigne, @idPo, @horoDebAPI, @horoFinAPI ;
    END;
    
    CLOSE popacking_cursor;
    DEALLOCATE popacking_cursor;
    
    
    -- ================================================================================================
    -- il reste soit des PO qui n'ont aucune date deb/fin API soit des PO qui n'ont qu'une date de fin
    -- D. Si des PO n'ont pas de date de fin et étaient avant le PO nouvellement mis à jour, on leur met une date de fin
    UPDATE p
    SET p.horoFinAPI=p2.horoDebAPI
    FROM PoPacking p,
    -- [[ recherche DU PO (un seul possible) avec l'ordre le plus haut avec une date de début API (= normalement, Po en cours)
    PoPacking p2 INNER JOIN
        (
            SELECT pInner.idLigne, max(pInner.ordre) ordreMax
            FROM PoPacking pInner
            WHERE pInner.horoDebAPI IS NOT NULL
            GROUP BY pInner.idLigne
        ) p3 ON p2.idLigne=p3.idLigne AND p2.ordre=p3.ordreMax
    -- fin recherche ]]
    WHERE p.horoFinAPI IS NULL 
      AND p.ordre < p2.ordre
      AND p.idLigne=p2.idLigne
    
    -- E. On met une date de début API à la date de fin API si on a une date de fin mais pas de date de début
    UPDATE PoPacking 
    SET horoDebAPI=horoFinAPI
    WHERE horoDebAPI IS NULL 
      AND horoFinAPI IS NOT NULL;
    
    -- Logs de ce qu'on va mettre à jour
    /*
    INSERT INTO [pg_commandorv2_logs].[dbo].[log_application] ([horodate],[categorie],[niveau],[message],[source],[thread],[trace])
    (
        SELECT  GetDate(),'syncCompteurs','DEBUG','Màj CPT','sp [synchroCompteurs]',null,
             'Ligne: ' + l.code 
             + '. Po: ' + p.numPo  + ' (qté à prod : ' + CAST(p.quantiteProduite as varchar(8)) + ')'
             + '. Cpt automate: ' +  CAST(ls.qteFlacon as varchar(8)) 
             + ' (' +  CAST((ls.qteFlacon) as varchar(8)) + ' - '+  CAST((p.quantiteProduite) as varchar(8)) + ' = '+  CAST((ls.qteFlacon-p.quantiteProduite) as varchar(8)) + ')'
            
        FROM  PoPacking p
            INNER JOIN [Ligne] l ON p.idLigne=l.id
            INNER JOIN [pg_commandorv2].[dbo].[vLigneSapCommandorV1] ls ON ls.codeSAP = 'B' + l.code 
              AND p.numPo LIKE '%'+ls.poPacking
        WHERE quantiteProduite<>ls.qteFlacon
          AND len(ls.poPacking)>=8
    )
    */
    
    -- F. Mise à jour du compteur du PO
    UPDATE p
    SET	quantiteProduite=ls.qteFlacon
    FROM PoPacking p
        INNER JOIN [Ligne] l ON p.idLigne=l.id
        INNER JOIN [pg_commandorv2].[dbo].[vLigneSapCommandorV1] ls ON ls.codeSAP = 'B' + l.code
          AND p.numPo LIKE '%'+ls.poPacking
    WHERE 
      len(ls.poPacking)>=8
      AND ls.qteFlacon > quantiteProduite -- on ne met à jour que si l'on augmente la quantité
    /*WHERE horoDebAPI IS NOT NULL 
      AND horoFinAPI IS NULL*/;
    
    /*
    UPDATE l
    SET numPoEnCours='inutilisé (voir POs)', compteur=-1
    --SET numPoEnCours=ls.poPacking, compteur=ls.qteFlacon
    -- SELECT *
    FROM Ligne l
        INNER JOIN  [pg_kanban].[dbo].[LIGNE_SAP] ls ON ls.codeSAP = 'B' + l.code 
    */
    
    END
    ```

2. vLigneSapCommandorV1

    ``` SQL
    -- dbo.vLigneSapCommandorV1 source
    
    ALTER VIEW dbo.vLigneSapCommandorV1
    AS
    SELECT        id, idLigneTremie, libelle, codeSAP, codeRTCIS, active, poPacking, qteFlacon, horodate
    FROM            pg_commandorv1.dbo.LIGNE_SAP;
    ```

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