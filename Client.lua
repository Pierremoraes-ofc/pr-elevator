local QBCore = exports['qb-core']:GetCoreObject()
local interactions = {}
local Elevators = {}
local ox_lib = exports.ox_lib
local resourceName = GetCurrentResourceName()
local playerJob = {}
local playerGang = {}
local ColorScheme = GlobalState.UIColors

function masterNotify(title, description, type)
    lib.notify({
        title = title,
        description = description,
        duration = 3500,
        type = type,
        position = Config.position
    })
end

RegisterNetEvent('pr-elevator:client:masterNotify', masterNotify)
-- opens the ui
RegisterNetEvent('pr-elevator:showmenu', function(index)
    SendNUIMessage({ action = 'showlift', data = Elevators.Elevator[index] })
    SetNuiFocus(true, true)
end)
-- hides the ui
RegisterNetEvent('pr-elevator:hidemenu', function(playerId)
    SendNUIMessage({ action = 'hidelift' })
    SetNuiFocus(false, false)
end)
-- handles changing floors
local function UseElevator(data)
    local ped = PlayerPedId()
    TriggerEvent("pr-elevator:hidemenu")
    if Config.Debug then
        print('UseElevator: ')
        print(json.encode(data))
    end
    QBCore.Functions.Progressbar("Call_Lift", Config.Locals[Config.UseLanguage].Waiting, Config.WaitTime, false, false, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "anim@apt_trans@elevator",
        anim = "elev_1",
        flags = 16,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, "anim@apt_trans@elevator", "elev_1", 1.0)
        DoScreenFadeOut(500)
        Wait(1000)
        if Config.UseSoundEffect then
            TriggerServerEvent("InteractSound_SV:PlayOnSource", "LiftSoundBellRing", 0.05)
        end
        --Elevators.Elevator[data.id]

        local vehicle = nil
        if IsPedInAnyVehicle(ped) then
            vehicle = GetVehiclePedIsIn(ped)
        end
        if vehicle ~= nil then
            SetEntityCoords(vehicle, data.floor.Coords.x, data.floor.Coords.y, data.floor.Coords.z, 0, 0, 0, true)
            SetEntityHeading(vehicle, data.floor.Coords.w)
        else
            SetEntityCoords(ped, data.floor.Coords.x, data.floor.Coords.y, data.floor.Coords.z, 0, 0, 0, false)
            SetEntityHeading(ped, data.floor.Coords.w)
        end
        Wait(1000)
        DoScreenFadeIn(600)
    end)
end
function AddInteraction(index, coords, keypass, tipo)
    interactions[index] = {
        id = index,
        name = 'elevator',
        coords = coords,
        distance = 5.0,
        interactDst = 2.5,
        options = {
            {
                label = index,
                action = function(entity, coords, args)
                    if keypass == '' then
                        TriggerEvent('pr-elevator:showmenu', index)
                    elseif keypass == playerJob.name or keypass == playerGang.name then
                        TriggerEvent('pr-elevator:showmenu', index)
                    elseif keypass == Config.keycard then
                        local toolItem = exports.ox_inventory:Search("slots", keypass)

                        if toolItem then
                            toolItem = toolItem[1]
                        end

                        if not toolItem then
                            masterNotify(Config.Locals[Config.UseLanguage].error,
                                Config.Locals[Config.UseLanguage].notItem, 'error')
                            return
                        end

                        if toolItem.metadata['acesso'] == tipo then
                            TriggerEvent('pr-elevator:showmenu', index)
                            return
                        end
                        masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notAcess,
                            'error')
                    else
                        -- Check if keypass is in Config.Jobs
                        local isJob = false
                        for _, v in pairs(Config.Jobs) do
                            if v == keypass then
                                isJob = true
                                break
                            end
                        end

                        if isJob then
                            -- If keypass is a job, show notification that access is denied
                            masterNotify(Config.Locals[Config.UseLanguage].error,
                                Config.Locals[Config.UseLanguage].notAcess, 'error')
                        else
                            -- If keypass is not a job, show password input dialog
                            local input = lib.inputDialog(Config.Locals[Config.UseLanguage].passwordElev, {
                                {
                                    type = 'input',
                                    password = true,
                                    label = Config.Locals[Config.UseLanguage].password,
                                    min = 1
                                },
                            })
                            if not input then return end
                            if input[1] ~= keypass then
                                masterNotify(Config.Locals[Config.UseLanguage].error,
                                    Config.Locals[Config.UseLanguage].invalid, 'error')
                                return false
                            end
                            TriggerEvent('pr-elevator:showmenu', index)
                        end
                    end
                end,
            },
        }
    }
    exports.interact:AddInteraction(interactions[index])
end

RegisterNetEvent(
    "onResourceStart",
    function(cocoteimoso)
        if cocoteimoso == GetCurrentResourceName() then
            local playerData = QBCore.Functions.GetPlayerData()
            playerJob = playerData.job
            playerGang = playerData.gang
            Elevators = lib.callback.await("pr-elevator:server:loadElevator", false)
            if Config.Debug then
                print(json.encode(Elevators))
            end
            for k, v in pairs(Elevators.Elevator) do
                for _, location in ipairs(v.locations) do
                    AddInteraction(v.name, location, v.keypass, v.tipo)
                end
            end
        end
    end
)
function NearestElevator()
    local player = PlayerPedId()
    local playerCoords = GetEntityCoords(player)

    local nearestElevator = nil
    local nearestDistance = math.huge

    for _, elevator in pairs(Elevators.Elevator) do
        for _, location in ipairs(elevator.locations) do
            local distance = Vdist(playerCoords.x, playerCoords.y, playerCoords.z, location.x, location.y, location.z)
            if Config.Debug then
                print('Vdist: ')
                print(distance)
                print('Elevador: ')
                print(json.encode(elevator))
                print('Vdist nearestDistance: ')
                print(json.encode(nearestDistance))
            end
            if distance < nearestDistance then
                nearestElevator = elevator
                nearestDistance = distance
            end
        end
    end

    return nearestElevator, nearestDistance
end

RegisterNUICallback('selectfloor', function(data, cb)
    local floorNumber = tonumber(data.number)

    -- Get the nearest elevator and its floors
    local nearestElevator, nearestDistance = NearestElevator()
    if nearestElevator then
        local selectedFloor = nearestElevator.Floors[floorNumber]
        if Config.Debug then
            print('nearestElevator: ')
            print(json.encode(nearestElevator))
            print('floorNumber: ')
            print(json.encode(floorNumber))
            print('nearestDistance: ')
            print(json.encode(nearestDistance))
        end
        if selectedFloor then
            -- Call the UseElevator function with the elevator and floor data
            UseElevator({ lift = nearestElevator, floor = selectedFloor })
            cb({ success = true, message = "Floor selected successfully" })
            TriggerEvent("pr-elevator:hidemenu")
        else
            cb({ success = false, message = "Invalid floor selection" })
            TriggerEvent("pr-elevator:hidemenu")
        end
    else
        cb({ success = false, message = "No elevator found" })
    end
end)
RegisterNUICallback('escape', function(_, cb)
    TriggerEvent("pr-elevator:hidemenu")
    cb("ok")
end)



--////////////////////////////////////////////////////////////
--///                       RAYCAST                        ///
--////////////////////////////////////////////////////////////

local function GetRayCoords(cb)
    masterNotify(Config.Locals[Config.UseLanguage].selectCoords, '', 'info')
    
    local active = true
    
    CreateThread(function()
        while active do
            Wait(0) -- Yield each frame
            
            local hit, entity, coords = lib.raycast.cam(1, 35)

            lib.showTextUI(
                string.format(
                Config.Locals[Config.UseLanguage].raycastInfo,
                    coords.x,
                    coords.y,
                    coords.z
                )
            )
            
            if hit then
                DrawSphere(coords.x, coords.y, coords.z, 0.2, 255, 0, 0, 0.2)
                if IsControlJustReleased(1, 38) then -- E
                    lib.hideTextUI()
                    active = false
                    cb(coords) -- Call the callback with coords
                    return
                end
            end
            
            if IsControlJustReleased(0, 44) then -- Q
                lib.hideTextUI()
                active = false
                cb(false) -- Call the callback with false
                return
            end
        end
    end)
end
lib.callback.register('pr-elevator:client:raycast', function()
    local result = nil
    
    GetRayCoords(function(coords)
        if coords then
            local heading = GetEntityHeading(PlayerPedId())
            lib.setClipboard(string.format("%.2f, %.2f, %.2f, %.2f", coords.x, coords.y, coords.z, heading))
            result = true
        else
            result = false
        end
    end)
    
    -- Wait for the result
    while result == nil do
        Wait(100)
    end
    
    return result
end)
exports('GetRayCoords', GetRayCoords)
local function Request(title, text, position)
    while lib.getOpenMenu() do
        Wait(100)
    end
    if not position then
        position = 'top-right'
    end
    local ctx = {
        id = 'mriRequest',
        title = title,
        position = position,
        canClose = false,
        options = { {
            label = Config.Locals[Config.UseLanguage].yes,
            icon = 'fa-regular fa-circle-check',
            description = text
        }, {
            label = Config.Locals[Config.UseLanguage].no,
            icon = 'fa-regular fa-circle-xmark',
            iconColor = ColorScheme.danger,
            description = text
        } }
    }
    local result = false
    lib.registerMenu(ctx, function(selected, scrollIndex, args)
        result = selected == 1
    end)
    lib.showMenu(ctx.id)
    while lib.getOpenMenu() == ctx.id do
        Wait(100)
    end
    return result
end
lib.callback.register('pr-elevator:client:request', function(title, text, position)
    return Request(title, text, position)
end)
exports('Request', Request)

--////////////////////////////////////////////////////////////
--///                      MENU OXLIB                      ///
--////////////////////////////////////////////////////////////

-- EDITAR ELEVADOR
local function editaElevadorMaster(elevadorId)
    -- Solicitar a lista de elevadores do servidor
    TriggerServerEvent('pr-elevator:server:getElevatorSelect', elevadorId)

    -- Escutar o evento que recebe os dados do elevador selecionado
    RegisterNetEvent('pr-elevator:client:receiveElevatorSelect', function(elevator)
        -- Check if elevator is an array and extract the first element if it is
        if type(elevator) == 'table' and elevator[1] then
            elevator = elevator[1]
            if Config.Debug then
                print(json.encode(elevator), 'Aqui estou!!')
            end
        end
        if not elevator or not elevator.id then
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].floorNotDb, 'info')
            return
        end

        -- Abrir o menu com as opções dinâmicas
        local input = lib.inputDialog(Config.Locals[Config.UseLanguage].createFloor, {
            {
                type = 'input',
                label = Config.Locals[Config.UseLanguage].floor,
                placeholder = elevator.floor_number, -- Número do andar
            },
            {
                type = 'input',
                label = Config.Locals[Config.UseLanguage].coordInteract,
                description = Config.Locals[Config.UseLanguage].coordIntDesc,
                placeholder = elevator.coords,
                --required = true
            },
            {
                type = 'checkbox',
                label = Config.Locals[Config.UseLanguage].myCds
            },
            {
                type = 'checkbox',
                label = Config.Locals[Config.UseLanguage].delFloor
            },
            {
                label = Config.Locals[Config.UseLanguage].retur,
                description = Config.Locals[Config.UseLanguage].returMenu,
                icon = 'fa-solid fa-arrow-left',
                onSelect = function()
                    lib.showContext('infoserver_menu') -- Retorna ao menu principal
                end
            }
        })

        -- Verifica se o usuário cancelou a operação
        if not input then
            return
        end

        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(PlayerPedId())
        local cudoce = ''
        local idid = ''
        if input[3] then
            cudoce = coords.x .. ', ' .. coords.y .. ', ' .. coords.z .. ', ' .. heading
        else
            cudoce = input[2] or elevator.coords
        end
        if input[1] ~= '' then
            idid = input[1]
        else
            idid = elevator.floor_number
            if Config.Debug then
                print('entrou no else do input 1')
                print(idid)
            end
        end

        local andarData = {
            id = elevator.id,
            floor_number = idid,
            coords = cudoce,
        }
        if Config.Debug then
            print(json.encode(andarData))
        end
        if input[4] then
            local resultado2 = lib.callback.await('pr-elevator:server:deleteAndar', false, elevator.id)
            if resultado2 then
                masterNotify(Config.Locals[Config.UseLanguage].info, Config.Locals[Config.UseLanguage].delFloorSuccess,
                    'info')
            else
                masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notPossible,
                    'error')
            end
        else
            local resultado = lib.callback.await('pr-elevator:server:editarandar', false, andarData)
            if resultado then
                masterNotify(Config.Locals[Config.UseLanguage].info, Config.Locals[Config.UseLanguage].editFloor, 'info')
            else
                masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notEditFloor,
                    'error')
            end
        end
        -- Retornar para o menu "infoserver_menu"
        lib.showContext('infoserver_menu')
    end)
end
--  GERENCIAR O ANDAR
local function gerenciarAndarSelect(elevadorId)
    -- Solicitar a lista de elevadores do servidor
    TriggerServerEvent('pr-elevator:server:getElevatorSelect', elevadorId)

    -- Escutar o evento que recebe os dados do elevador selecionado
    RegisterNetEvent('pr-elevator:client:receiveElevatorSelect', function(elevator)
        if Config.Debug then
            print(json.encode(elevator), 'Sei lá!!')
        end

        -- Check if elevator is an array and extract the first element if it is
        if type(elevator) == 'table' and elevator[1] then
            elevator = elevator[1]
            if Config.Debug then
                print(json.encode(elevator), 'Aqui estou!!')
            end
        end

        if not elevator or not elevator.id then
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].floorNotDb, 'info')
            return
        end

        -- Construir a lista de opções para o menu
        local menuOptions = {
            {
                title = Config.Locals[Config.UseLanguage].editFloorMenu .. elevator.floor_number,
                description = Config.Locals[Config.UseLanguage].notInfoFloor,
                icon = 'elevator',
                onSelect = function()
                    editaElevadorMaster(elevator.id)
                end
            },
            {
                title = Config.Locals[Config.UseLanguage].tpwayFloor,
                description = Config.Locals[Config.UseLanguage].runFloor,
                icon = 'elevator',
                onSelect = function()
                    -- Parse the coordinates string into a vector
                    local x, y, z, heading = string.match(elevator.coords, "([^,]+), ([^,]+), ([^,]+), ([^,]+)")
                    if x and y and z then
                        SetEntityCoords(PlayerPedId(), tonumber(x), tonumber(y), tonumber(z), 0, 0, 0, false)
                        if heading then
                            SetEntityHeading(PlayerPedId(), tonumber(heading))
                        end
                    else
                        masterNotify(Config.Locals[Config.UseLanguage].error,
                            Config.Locals[Config.UseLanguage].cdsInvalid, 'error')
                    end
                end
            },
            {
                title = Config.Locals[Config.UseLanguage].delFloor,
                description = Config.Locals[Config.UseLanguage].delFloors,
                icon = 'elevator',
                onSelect = function()
                    local inputo = lib.inputDialog(Config.Locals[Config.UseLanguage].delFloor, {
                        {
                            type = 'input',
                            label = Config.Locals[Config.UseLanguage].digtExc,
                            placeholder = Config.Locals[Config.UseLanguage].delet,
                            required = true
                        }
                    })
                    if not inputo then
                        return
                    end
                    -- Fix: inputo is an array, so we need to check inputo[1]
                    if inputo[1] == Config.Locals[Config.UseLanguage].delet then
                        local resultado2 = lib.callback.await('pr-elevator:server:deleteAndar', false, elevator.id)
                        if resultado2 then
                            masterNotify(Config.Locals[Config.UseLanguage].info,
                                Config.Locals[Config.UseLanguage].delFloorSuccess, 'info')
                        else
                            masterNotify(Config.Locals[Config.UseLanguage].error,
                                Config.Locals[Config.UseLanguage].notPossible, 'error')
                        end
                    else
                        masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage]
                        .infoDelet, 'error')
                    end
                end
            },
            {
                title = Config.Locals[Config.UseLanguage].retur,
                description = Config.Locals[Config.UseLanguage].returMenu,
                icon = 'fa-solid fa-arrow-left',
                onSelect = function()
                    lib.showContext('infoserver_menu')
                end
            }
        }

        lib.registerContext({
            id = 'menu_gerenciar_predio',
            title = Config.Locals[Config.UseLanguage].managerId .. elevator.floor_number,
            description = Config.Locals[Config.UseLanguage].actionFloor,
            options = menuOptions
        })

        -- Add this line to show the menu after registering it
        lib.showContext('menu_gerenciar_predio')
    end)
end
-- GERENCIAR ELEVADOR
local function gerenciarMeusElevador(predioId, predioNome)
    -- Solicitar lista de elevadores do servidor
    TriggerServerEvent('pr-elevator:server:getElevatorList', predioId)

    -- Escutar evento para receber a lista de elevadores
    RegisterNetEvent('pr-elevator:client:receiveElevatorList', function(elevatorList)
        if not elevatorList or #elevatorList == 0 then
            Notify(locale(msg), 'warning')
            masterNotify(Config.Locals[Config.UseLanguage].info, Config.Locals[Config.UseLanguage].notEncounter, 'info')
            return
        end

        -- Construir menu para os elevadores
        local menuOptions = {}
        for _, elevator in ipairs(elevatorList) do
            table.insert(menuOptions, {
                title = Config.Locals[Config.UseLanguage].floorF .. elevator.floor_number,
                description = Config.Locals[Config.UseLanguage].managerCds .. elevator.coords,
                icon = 'house',
                onSelect = function()
                    if Config.Debug then
                        print('Selecionado Elevador: ' .. elevator.id)
                    end
                    gerenciarAndarSelect(elevator.id)
                end
            })
        end

        -- Adicionar opção para voltar
        table.insert(menuOptions, {
            title = Config.Locals[Config.UseLanguage].retur,
            description = Config.Locals[Config.UseLanguage].returMenu,
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                lib.showContext('infoserver_menu') -- Retornar ao menu de prédios
            end
        })

        -- Mostrar menu
        lib.registerContext({
            id = 'menu_elevadores',
            title = Config.Locals[Config.UseLanguage].managerElevFloors .. predioNome,
            description = Config.Locals[Config.UseLanguage].listFloors,
            options = menuOptions
        })
        lib.showContext('menu_elevadores')
    end)
end
-- EDITAR ELEVADOR
local function editaPredioMaster(elevadorId)
    -- Solicitar a lista de elevadores do servidor
    TriggerServerEvent('pr-elevator:server:getPredioSelect', elevadorId)

    -- Escutar o evento que recebe os dados do elevador selecionado
    RegisterNetEvent('pr-elevator:client:receivePredioSelect', function(predio)
        -- Check if elevator is an array and extract the first element if it is
        if type(predio) == 'table' and predio[1] then
            predio = predio[1]
            if Config.Debug then
                print(json.encode(predio), 'Aqui estou!!')
            end
        end
        if not predio or not predio.id then
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].elevNotDb, 'info')
            return
        end

        -- Abrir o menu com as opções dinâmicas
        local input = lib.inputDialog(Config.Locals[Config.UseLanguage].editElevator, {
            {
                type = 'input',
                label = Config.Locals[Config.UseLanguage].nameElevator,
                placeholder = predio.name, -- Utiliza o nome do Elevador
            },
            {
                type = 'input',
                label = Config.Locals[Config.UseLanguage].metadataCard,
                description = Config.Locals[Config.UseLanguage].exempleCard,
                placeholder = tostring(predio.tipo), -- Número do andar (convertido para string)
            },
            {
                type = 'input',
                label = Config.Locals[Config.UseLanguage].passwordElev,
                description = Config.Locals[Config.UseLanguage].exemplePassword,
                placeholder = tostring(predio.keypass),
            },
            {
                type = 'checkbox',
                label = Config.Locals[Config.UseLanguage].delElevator
            },
            {
                label = Config.Locals[Config.UseLanguage].retur,
                description = Config.Locals[Config.UseLanguage].returMenu,
                icon = 'fa-solid fa-arrow-left',
                onSelect = function()
                    lib.showContext('infoserver_menu') -- Retorna ao menu principal
                end
            }
        })

        -- Verifica se o usuário cancelou a operação
        if not input then
            return
        end

        for k, v in pairs(Config.Jobs) do -- Added 'in' keyword here
            if v == input[2] then
                masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].jobCard, 'error')
                return
            end
        end
        if input[2] ~= '' and input[3] ~= '' then
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].keyCardPassword,
                'error')
            return
        end
        if input[3] ~= '' then
            input[2] = ''
        end
        if input[2] ~= '' then
            input[3] = ''
        end
        if input[1] == '' then
            input[1] = predio.name
        end
        if input[2] == '' then
            input[2] = predio.tipo
        end
        if input[3] == '' then
            input[3] = predio.keypass
        end


        -- Se o checkbox excluir elevador estiver marcado, trata a exclusão
        if input[4] then -- O checkbox será o terceiro elemento
            local resultado2 = lib.callback.await('pr-elevator:server:deletePredio', false, predio.id)
            if resultado2 then
                masterNotify(Config.Locals[Config.UseLanguage].info, Config.Locals[Config.UseLanguage].elevatorDel,
                    'info')
            else
                masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notDelElevator,
                    'error')
            end
        else
            -- Atualizar os dados do Elevador (caso não seja para excluir)
            local predioData = {
                id = predio.id,
                name = input[1],
                tipo = input[2],
                keypass = input[3]
            }

            -- Usar lib.callback para editar o Elevador
            local resultado = lib.callback.await('pr-elevator:server:editarPredio', false, predioData)

            if resultado then
                masterNotify(Config.Locals[Config.UseLanguage].infoSuccess,
                    Config.Locals[Config.UseLanguage].refreshElevator, 'success')
            else
                masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notRefreshElev,
                    'error')
            end
        end
        -- Retornar para o menu "infoserver_menu"
        lib.showContext('infoserver_menu')
    end)
end
-- -- Função para gerenciar um único Elevador
local function PreGerenciarPredios(torreId, nome)
    local menuOptions = {
        {
            title = Config.Locals[Config.UseLanguage].editElevator .. ': ' .. nome,
            description = Config.Locals[Config.UseLanguage].editElevDesc,
            icon = 'fa-solid fa-building', -- Ícone do menu
            onSelect = function()
                editaPredioMaster(torreId)
            end
        },
        {
            title = Config.Locals[Config.UseLanguage].managerFloors,
            description = Config.Locals[Config.UseLanguage].managerFloorsDesc,
            icon = 'elevator',
            arrow = true,
            onSelect = function()
                gerenciarMeusElevador(torreId, nome)
            end
        },
        {
            title = Config.Locals[Config.UseLanguage].deletAll,
            description = Config.Locals[Config.UseLanguage].deletAllInfo .. nome,
            icon = 'fa-solid fa-building', -- Ícone do menu
            onSelect = function()
                local inputo = lib.inputDialog(Config.Locals[Config.UseLanguage].delElevator, {
                    {
                        type = 'input',
                        label = Config.Locals[Config.UseLanguage].digtExc,
                        placeholder = Config.Locals[Config.UseLanguage].delet,
                        required = true
                    }
                })
                if not inputo then
                    return
                end
                if inputo[1] == Config.Locals[Config.UseLanguage].delet then
                    local resultado2 = lib.callback.await('pr-elevator:server:deletePredio', false, torreId)
                    if resultado2 then
                        masterNotify(Config.Locals[Config.UseLanguage].info,
                            Config.Locals[Config.UseLanguage].elevatorDel, 'info')
                    else
                        masterNotify(Config.Locals[Config.UseLanguage].error,
                            Config.Locals[Config.UseLanguage].notDelElevator, 'error')
                    end
                end
            end
        },
        {
            title = Config.Locals[Config.UseLanguage].retur,
            description = Config.Locals[Config.UseLanguage].returMenu,
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                lib.showContext('infoserver_menu')
            end
        }
    }

    lib.registerContext({
        id = 'menu_gerenciar_predio',
        title = Config.Locals[Config.UseLanguage].managerElevat .. nome,
        description = Config.Locals[Config.UseLanguage].managerElevatDesc,
        options = menuOptions
    })

    lib.showContext('menu_gerenciar_predio')
end
-- Escutar o evento que recebe a lista de Elevador
local function GerenciarPredios()
    -- Solicitar a lista de Elevador do servidor
    TriggerServerEvent('pr-elevator:server:getTowerList')
    RegisterNetEvent('pr-elevator:client:receiveTowerList', function(towerList)
        if not towerList or #towerList == 0 then
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notElevatorDb,
                'error')
            return
        end

        -- Construir a lista de opções para o menu
        local menuOptions = {}
        for _, tower in ipairs(towerList) do
            table.insert(menuOptions, {
                title = tower.name,            -- Nome do Elevador visível no menu
                description = Config.Locals[Config.UseLanguage].clickManageElevator,
                icon = 'fa-solid fa-building', -- Ícone do menu
                arrow = true,
                onSelect = function()
                    PreGerenciarPredios(tower.id, tower.name)
                end
            })
        end

        -- Adicionar uma opção para voltar ao menu principal
        table.insert(menuOptions, {
            title = Config.Locals[Config.UseLanguage].retur,
            description = Config.Locals[Config.UseLanguage].returMenu,
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                lib.showContext('infoserver_menu')
            end
        })

        -- Registrar o menu com as opções construídas
        lib.registerContext({
            id = 'gerenciadorPredios',
            title = Config.Locals[Config.UseLanguage].managerElevator,
            description = Config.Locals[Config.UseLanguage].managerElevatorDesc,
            options = menuOptions
        })

        -- Exibir o menu criado
        lib.showContext('gerenciadorPredios')
    end)
end
-- CRIAR ELEVADORES
local function createElevador()
    -- Solicitar a lista de Elevadors do servidor
    TriggerServerEvent('pr-elevator:server:getTowerList')

    -- Escutar o evento que recebe a lista de Elevadors
    RegisterNetEvent('pr-elevator:client:receiveTowerList', function(towerList)
        if not towerList or #towerList == 0 then
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notElevatorDb, 'info')
            return
        end

        -- Construir a lista de opções
        local towerOptions = {}
        for _, tower in ipairs(towerList) do
            towerOptions[#towerOptions + 1] = {
                label = tower.name, -- Nome do Elevador visível no menu
                value = tower.id,   -- ID do Elevador usado internamente
            }
        end

        -- Abrir o menu com as opções dinâmicas
        local input = lib.inputDialog(Config.Locals[Config.UseLanguage].createFloor,
            {
                {
                    type = 'select',        -- Define como um campo de seleção
                    label = Config.Locals[Config.UseLanguage].selectElevator,
                    options = towerOptions, -- Usa as opções geradas dinamicamente
                    required = true
                },
                {
                    type = 'input',
                    label = Config.Locals[Config.UseLanguage].floor,
                    description = Config.Locals[Config.UseLanguage].orderFloor,
                    placeholder = '1, 2, 3',
                    required = true
                },
                {
                    type = 'input',
                    label = Config.Locals[Config.UseLanguage].elevatorInteract,
                    description = Config.Locals[Config.UseLanguage].newCdsInsert,
                    placeholder = '1.111, 2.222, 3.333, 4.444',
                    --required = true
                },
                {
                    label = Config.Locals[Config.UseLanguage].retur,
                    description = Config.Locals[Config.UseLanguage].returMenu,
                    icon = 'fa-solid fa-arrow-left',
                    onSelect = function()
                        lib.showContext('infoserver_menu') -- Retorna ao menu principal
                    end
                }
            })

        if not input then
            return
        end

        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(PlayerPedId())

        if input[3] == '' then
            input[3] = coords.x .. ', ' .. coords.y .. ', ' .. coords.z .. ', ' .. heading
        end

        -- Preparar os dados para salvar no banco de dados
        local andarData = {
            elevadorId = input[1],
            floorNumber = tonumber(input[2]),
            coords = input[3]
        }

        -- Chamar o callback para salvar no banco de dados
        local resultado = lib.callback.await('pr-elevator:server:salvarAndar', false, andarData)

        if resultado then
            -- Exibir notificação de sucesso
            masterNotify(Config.Locals[Config.UseLanguage].infoSuccess, Config.Locals[Config.UseLanguage]
            .addSuccessFloor, 'success')
        else
            -- Exibir notificação de erro
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].notAddFloor, 'error')
        end

        -- Retornar para o menu "infoserver_menu"
        lib.showContext('infoserver_menu')
    end)
end
-- CRIAR PREDIO PARA ELEVADORES
local function createPredio()
    local input = lib.inputDialog(Config.Locals[Config.UseLanguage].elevSystem, {
        {
            type = 'input',
            label = Config.Locals[Config.UseLanguage].nameElevator,
            placeholder = 'L.S.P.D',
            required = true
        },
        {
            type = 'input',
            label = Config.Locals[Config.UseLanguage].metadataCard,
            description = Config.Locals[Config.UseLanguage].exempleCard,
            placeholder = 'pierre_card',
        },
        {
            type = 'input',
            label = Config.Locals[Config.UseLanguage].passwordElev,
            description = Config.Locals[Config.UseLanguage].exemplePassword,
            placeholder = '1234',
        },
        {
            label = Config.Locals[Config.UseLanguage].retur,
            description = Config.Locals[Config.UseLanguage].returMenu,
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                lib.showContext('infoserver_menu') -- Retorna ao menu principal
            end
        }
    })

    if not input then
        return
    end
    for k, v in pairs(Config.Jobs) do -- Added 'in' keyword here
    if v == input[2] then
            masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].jobCard, 'error')
            return
        end
    end
    if input[2] ~= '' and input[3] ~= '' then
        masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].keyCardPassword, 'error')
        return
    end

    -- Prepara os dados para salvar no banco de dados
    local elevadorData = {
        name = input[1],
        tipo = input[2] or '',
        keypass = input[3] or ''
    }

    -- Chama o callback para salvar no banco de dados
    local resultado = lib.callback.await('pr-elevator:server:salvarElevador', false, elevadorData)

    if resultado then
        -- Exibe aviso de sucesso
        masterNotify(Config.Locals[Config.UseLanguage].infoSuccess, Config.Locals[Config.UseLanguage].infoSuccessInfo,
            'success')
    else
        -- Exibe aviso de erro
        masterNotify(Config.Locals[Config.UseLanguage].error, Config.Locals[Config.UseLanguage].errorInfo, 'error')
    end

    -- Retornar para o menu "infoserver_menu"
    lib.showContext('infoserver_menu')
end
-- CRIAR PREDIO PARA ELEVADORES
local function criarCartao()
    local input = lib.inputDialog(Config.Locals[Config.UseLanguage].elevSystem, {
        {
            type = 'checkbox',
            label = Config.Locals[Config.UseLanguage].myInventory
        },
        {
            type = 'input',
            label = Config.Locals[Config.UseLanguage].idPlayer,
            description = Config.Locals[Config.UseLanguage].idPlayerDesc,
            placeholder = '1',
        },
        {
            type = 'input',
            label = Config.Locals[Config.UseLanguage].amount,
            description = Config.Locals[Config.UseLanguage].amountDesc,
            placeholder = '100',
            required = true
        },
        {
            type = 'input',
            label = Config.Locals[Config.UseLanguage].metadataName,
            placeholder = Config.Locals[Config.UseLanguage].metadataNameDesc,
            required = true
        },
        {
            label = Config.Locals[Config.UseLanguage].retur,
            description = Config.Locals[Config.UseLanguage].returMenu,
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                lib.showContext('infoserver_menu') -- Retorna ao menu principal
            end
        }
    })

    if not input then
        return
    end

    local playerId = ''
    if input[1] then
        playerId = GetPlayerServerId(PlayerId())
    else
        playerId = input[2]
    end
    if Config.Debug then
        print('addcard' .. playerId .. ' ' .. input[3] .. ' ' .. input[4])
    end

    ExecuteCommand(Config.addCard .. ' ' .. playerId .. ' ' .. input[3] .. ' ' .. input[4])
    masterNotify(Config.Locals[Config.UseLanguage].infoSuccess, Config.Locals[Config.UseLanguage].cardSuccess, 'success')
    lib.showContext('infoserver_menu')
end
--Menu de Gerenciamento
lib.registerContext({
    id = 'infoserver_menu',
    title = Config.Locals[Config.UseLanguage].menuElevator,
    options = {
        {
            title = Config.Locals[Config.UseLanguage].managerElevator,
            description = Config.Locals[Config.UseLanguage].managerElevatorInfo,
            icon = 'fa-solid fa-cogs',
            iconAnimation = 'fade',
            arrow = true,
            onSelect = function()
                GerenciarPredios()
            end
        },
        {
            title = Config.Locals[Config.UseLanguage].createCard,
            description = Config.Locals[Config.UseLanguage].createCardInfo,
            icon = 'fa-solid fa-credit-card',
            iconAnimation = 'fade',
            onSelect = function()
                criarCartao()
            end
        },
        {
            title = Config.Locals[Config.UseLanguage].newFloor,
            description = Config.Locals[Config.UseLanguage].createFloorDesc,
            icon = 'elevator',
            iconAnimation = 'fade',
            onSelect = function()
                createElevador()
            end
        },
        {
            title = Config.Locals[Config.UseLanguage].newElevator,
            description = Config.Locals[Config.UseLanguage].createElevator,
            icon = 'fa-solid fa-cogs',
            iconAnimation = 'fade',
            onSelect = function()
                createPredio()
            end
        },
    }
})
--Eventos
if Config.OpenKeybind then
    RegisterKeyMapping("info", "infoserver_menu", "keyboard", Config.KeyBind)
    RegisterCommand('info', function()
        lib.progressCircle({
            duration = 3000,
            position = 'bottom',
            label = 'Pierre Elevadores',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
            },
            anim = {
                dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a',
                clip = 'idle_a'
            },
            prop = {
                model = `prop_cs_tablet`,
                pos = vec3(-0.05, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        })
        Citizen.Wait(500)
        lib.showContext('infoserver_menu')
    end)
end
RegisterNetEvent('pr-elevator:client:startLiftCreator', function()
    lib.showContext('infoserver_menu')
end)
