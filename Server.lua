lib.addCommand('elevador', {
    help = Config.Locals[Config.UseLanguage].helpcomm,
    restricted = 'group.admin'
}, function(source, args, raw)
    TriggerClientEvent('pr-elevator:client:startLiftCreator', source)
end)
lib.addCommand(Config.RaycastCommand, {
    help = 'Pegar coordenadas por RayCast',
    restricted = 'group.admin'
}, function(source)
    if Config.Raycast then
        lib.callback.await('pr-elevator:client:raycast', source)
        TriggerClientEvent('pr-elevator:client:masterNotify', target, "RayCast",
            Config.Locals[Config.UseLanguage].raycastDesc, 'success')
    else
        TriggerClientEvent('pr-elevator:client:masterNotify', target, "RayCast",
            Config.Locals[Config.UseLanguage].raycastDisabled, 'error')
    end
end)
local Elevators = { Elevator = {} }

--function LoadElevatorsFromDB()
lib.callback.register('pr-elevator:server:loadElevator', function(source)
    if not Config.UseDatabase then return end

    -- Example using MySQL-async library (common in FiveM)
    local elevators = MySQL.query.await('SELECT * FROM elevators')
    if not elevators or #elevators == 0 then
        if Config.Debug then
            print("No elevators found in the database.")
        end
        return
    end
    if Config.Debug then
        print("Elevators found:", #elevators)
    end
    for i = 1, #elevators do
        local elevator = elevators[i]

        -- Create elevator entry with proper format
        Elevators.Elevator[i] = {
            name = elevator.name,
            keypass = elevator.keypass,
            tipo = elevator.tipo,
            locations = {}, -- Initialize empty locations array, will be filled from floor data
            Floors = {}
        }

        -- Load floors for this elevator
        local floors = MySQL.query.await('SELECT * FROM elevator_floors WHERE elevator_id = ?', { elevator.id })
        if not floors or #floors == 0 then
            if Config.Debug then
                print("No floors found for elevator:", elevator.name)
            end
            --return
            goto continue
        end
        if Config.Debug then
            print("Floors found for elevator", elevator.name, ":", #floors)
        end

        -- Process each floor and also use it to populate locations
        for j = 1, #floors do
            local floor = floors[j]
            local floorNumber = j - 1 -- Use floor index as floor number (starting from 0)

            -- Parse coordinates string to vector4
            local coordsStr = floor.coords
            local x, y, z, h = coordsStr:match("([%d.-]+),?%s*([%d.-]+),?%s*([%d.-]+),?%s*([%d.-]+)")

            if x and y and z and h then
                -- Add to Floors
                Elevators.Elevator[i].Floors[floorNumber] = {
                    Coords = vector4(tonumber(x), tonumber(y), tonumber(z), tonumber(h))
                }

                -- Also add to locations (using the same coordinates but as vector3)
                table.insert(Elevators.Elevator[i].locations, vector3(tonumber(x), tonumber(y), tonumber(z)))
            else
                if Config.Debug then
                    print("Invalid coordinates format for floor:", j - 1)
                end
            end
        end
        ::continue::
    end
    if Config.Debug then
        print(json.encode(Elevators))
    end
    return Elevators
end)
function loadDb()
    print("^2[PR] ^7Verificando a existencia da tabela elevators no banco de dados...")
    exports.oxmysql:execute(
        [[
            CREATE TABLE IF NOT EXISTS `elevators` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) NOT NULL,
            `keypass` varchar(155) NOT NULL,
            `tipo` varchar(155) NOT NULL,
            PRIMARY KEY (`id`)
            );
        ]]
    )
    print("^2[PR] ^7Verificando a existencia da tabela elevator_floors no banco de dados...")
    exports.oxmysql:execute(
        [[
            CREATE TABLE IF NOT EXISTS `elevator_floors` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `elevator_id` int(11) NOT NULL,
            `floor_number` int(11) NOT NULL,
            `coords` longtext NOT NULL,
            PRIMARY KEY (`id`),
            KEY `elevator_id` (`elevator_id`),
            CONSTRAINT `elevator_floors_ibfk_1` FOREIGN KEY (`elevator_id`) REFERENCES `elevators` (`id`) ON DELETE CASCADE
            );
        ]]
    )
    print("^2[PR] ^7Verificação concluida todos os dados foram criado no banco de dados...")
end

RegisterNetEvent(
    "onResourceStart",
    function(resName)
        if resName == GetCurrentResourceName() then
            loadDb()
        end
    end
)






lib.addCommand(Config.addCard, {
        help = 'Adicionar cartão de acesso com metadados ao inventário de jogadores',
        params = {
            {
                name = 'target',
                type = 'playerId',
                help = 'Player ID',
                optional = true
            },
            {
                name = 'item',
                type = 'number',
                help = 'Quantidade de cartões',
            },
            {
                name = 'metadata',
                type = 'string',
                help = 'Tipo de acesso(policia, hospital, etc)',
            }
        },
        restricted = 'admin'
    },
    function(source, args)
        local target = args.target or source

        local metadata = {
            acesso = args.metadata,
            description = 'Cartão de acesso: ' .. args.metadata
        }

        local success = exports.ox_inventory:AddItem(target, Config.keycard, args.item, metadata)

        if success then
            -- Fix: Pass all three parameters to the event
            TriggerClientEvent('pr-elevator:client:masterNotify', target, Config.Locals[Config.UseLanguage].infoSuccess,
                Config.Locals[Config.UseLanguage].cardSuccess, 'success')
        else
            -- Fix: Pass all three parameters to the event
            TriggerClientEvent('pr-elevator:client:masterNotify', target, Config.Locals[Config.UseLanguage].error,
                Config.Locals[Config.UseLanguage].notAddCard, 'error')
        end
    end)
--  edita andar inteiro
lib.callback.register('pr-elevator:server:editarandar', function(source, andarData)
    local src = source
    if Config.Debug then
        print(json.encode(andarData))
    end
    -- Verificar se os dados necessários estão presentes
    if not andarData or not andarData.id then
        return false
    end

    -- Preparar a query SQL - Corrigido para usar a tabela elevator_floors
    local query = 'UPDATE elevator_floors SET floor_number = ?, coords = ? WHERE id = ?'
    local params = { andarData.floor_number, andarData.coords, andarData.id }

    -- Executar a query no banco de dados
    local success = MySQL.update.await(query, params)

    if success then
        -- Recarregar os dados dos elevadores
        --LoadElevatorsFromDB()

        -- Notificar todos os clientes para atualizar seus dados
        --TriggerClientEvent('pr-elevator:client:atualizarElevadores', -1)
        return true
    else
        return false
    end
end)
--  deleta andar inteiro
lib.callback.register('pr-elevator:server:deleteAndar', function(source, predioId)
    if Config.Debug then
        print(predioId, 'ID do elevador')
    end
    -- Primeiro, excluir os andares associados ao prédio
    local queryFloors = "DELETE FROM elevator_floors WHERE id = ?"
    local paramsFloors = { predioId }

    local successFloors = MySQL.update.await(queryFloors, paramsFloors)

    if successFloors then
        -- Recarregar os dados dos elevadores após a exclusão
        --LoadElevatorsFromDB()
        -- Notificar todos os clientes para atualizar seus dados
        --TriggerClientEvent('pr-elevator:client:atualizarElevadores', -1)
        return true
    else
        return false
    end
end)
--  apaga elevador e seus andares
lib.callback.register('pr-elevator:server:deletePredio', function(source, predioId)
    -- Primeiro, excluir os andares associados ao prédio
    local queryFloors = "DELETE FROM elevator_floors WHERE elevator_id = ?"
    local paramsFloors = { predioId }

    local successFloors = MySQL.update.await(queryFloors, paramsFloors)

    -- Depois, excluir o prédio
    local queryPredio = "DELETE FROM elevators WHERE id = ?"
    local paramsPredio = { predioId }

    local successPredio = MySQL.update.await(queryPredio, paramsPredio)

    if successPredio then
        -- Recarregar os dados dos elevadores após a exclusão
        --LoadElevatorsFromDB()
        -- Notificar todos os clientes para atualizar seus dados
        --TriggerClientEvent('pr-elevator:client:atualizarElevadores', -1)
        return true
    else
        return false
    end
end)
-- Callback para editar dados do prédio
lib.callback.register('pr-elevator:server:editarPredio', function(source, predioData)
    local src = source

    -- Verificar se os dados necessários estão presentes
    if not predioData or not predioData.id then
        return false
    end
    local params = {}
    -- Preparar a query SQL
    local query = 'UPDATE elevators SET name = ?, keypass = ?, tipo = ? WHERE id = ?'
    if predioData.tipo ~= '' then
        params = { predioData.name, 'security_card_01', predioData.tipo, predioData.id }
    else
        params = { predioData.name, predioData.keypass, predioData.tipo, predioData.id }
    end

    -- Executar a query no banco de dados
    local success = MySQL.update.await(query, params)

    if success then
        -- Recarregar os dados dos elevadores
        --LoadElevatorsFromDB()
        -- Notificar todos os clientes para atualizar seus dados
        --TriggerClientEvent('pr-elevator:client:atualizarElevadores', -1)
        return true
    else
        return false
    end
end)
-- Callback para salvar andares do elevador
lib.callback.register('pr-elevator:server:salvarAndar', function(source, andarData)
    local src = source

    -- Verificar se os dados necessários estão presentes
    if not andarData or not andarData.elevadorId or not andarData.floorNumber then
        return false
    end

    -- Preparar a query SQL
    local query = 'INSERT INTO elevator_floors (elevator_id, floor_number, coords) VALUES (?, ?, ?)'
    local params = { andarData.elevadorId, andarData.floorNumber, andarData.coords }

    -- Executar a query no banco de dados
    local success = MySQL.insert.await(query, params)

    if success then
        --LoadElevatorsFromDB()
        -- Notificar todos os clientes para atualizar seus dados
        --TriggerClientEvent('pr-elevator:client:atualizarElevadores', -1)
        return true
    else
        return false
    end
end)
-- Adicione este callback no seu arquivo Server.lua
lib.callback.register('pr-elevator:server:salvarElevador', function(source, elevadorData)
    local src = source
    local params = {}
    -- Verifica se os dados necessários estão presentes
    if not elevadorData or not elevadorData.name then
        return false
    end
    -- Prepara a query SQL
    local query = 'INSERT INTO elevators (name, keypass, tipo) VALUES (?, ?, ?)'

    if elevadorData.tipo ~= '' then
        params = { elevadorData.name, 'security_card_01', elevadorData.tipo }
    else
        params = { elevadorData.name, elevadorData.keypass, elevadorData.tipo }
    end

    -- Executa a query no banco de dados
    local success = MySQL.insert.await(query, params)

    if success then
        -- Atualiza os dados em cache se necessário
        -- Notifica todos os clientes para atualizar seus dados
        --TriggerClientEvent('pr-elevator:client:atualizarElevadores', -1)
        return true
    else
        return false
    end
end)
--  carrega dados do andar especificado
RegisterNetEvent('pr-elevator:server:getElevatorSelect', function(id)
    local src = source                                                  -- Jogador que fez a solicitação
    local query =
    "SELECT id, floor_number, coords FROM elevator_floors WHERE id = ?" -- Corrigido para selecionar todos os campos necessários
    local params = { id }

    local result = MySQL.query.await(query, params)

    -- Verifica se encontrou algum resultado
    if result and #result > 0 then
        -- Enviar a lista de dados do elevador para o cliente
        TriggerClientEvent('pr-elevator:client:receiveElevatorSelect', src, result)
    else
        TriggerClientEvent('pr-elevator:client:notify', src, 'Elevador não encontrado.')
    end
end)
--  carrega os elevadores
RegisterNetEvent('pr-elevator:server:getElevatorList', function(forenkey)
    local src =
        source -- Jogador que fez a solicitação

    local query =
    "SELECT id, floor_number, coords FROM elevator_floors WHERE elevator_id = @elevator_id" -- Buscar elevadores pelo forenkey
    local params = { ['@elevator_id'] = forenkey }

    local result = MySQL.query.await(query, params)

    if result and #result > 0 then
        -- Enviar a lista de dados do elevador para o cliente
        TriggerClientEvent('pr-elevator:client:receiveElevatorList', src, result)
    else
        TriggerClientEvent('pr-elevator:client:notify', src, 'Elevador não encontrado.')
    end
end)
--  Carrega os Elevadores no menu de criaçao
RegisterNetEvent('pr-elevator:server:getTowerList', function()
    local src = source                                                   -- Jogador que fez a solicitação
    local result = MySQL.query.await("SELECT id, name FROM `elevators`") -- Buscar apenas `id` e `name`

    if result and #result > 0 then
        -- Enviar a lista de dados do elevador para o cliente
        TriggerClientEvent('pr-elevator:client:receiveTowerList', src, result)
    else
        TriggerClientEvent('pr-elevator:client:notify', src, 'Elevador não encontrado.')
    end
end)
--  mostrar elevador selecionado
RegisterNetEvent('pr-elevator:server:getPredioSelect', function(id)
    local src = source                                                         -- Jogador que fez a solicitação
    local query = "SELECT id, name, keypass, tipo FROM elevators WHERE id = ?" -- Corrigido para usar as colunas corretas
    local params = { id }

    local result = MySQL.query.await(query, params)

    if result and #result > 0 then
        -- Enviar a lista de dados do elevador para o cliente
        TriggerClientEvent('pr-elevator:client:receivePredioSelect', src, result)
    else
        TriggerClientEvent('pr-elevator:client:notify', src, 'Elevador não encontrado.')
    end
end)
