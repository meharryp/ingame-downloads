if SERVER then
	util.AddNetworkString( "RSWorkshop" )

	local collection = CreateConVar( "wsdl_collection", "", { FCVAR_ARCHIVE, FCVAR_REPLICATED } )
	local overrideRSWorkshop = CreateConVar( "wsdl_overrideresource", 0, { FCVAR_ARCHIVE }, "Expriemental: Override resource.AddWorkshop. This will completly stop the client from downloading any addons on join, even if it's resource.AddWorkshop." )

	if overrideRSWorkshop then
		local addWorkshops = {}

		function resource.AddWorkshop( id )
			addWorkshops[ id ] = true
		end

		hook.Add( "PlayerInitialSpawn", "OverrideRSWorkshop", function( ply )
			net.Start( "RSWorkshop" )
			net.WriteTable( addWorkshops )
			net.Send( ply )
		end )
	end
else
	local collection = CreateConVar( "wsdl_collection", "", { FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE } )

	local toDownload = {}
	local currentAddon = 1

	local function DownloadSteamworksAddon( id, callback )
		steamworks.FileInfo( id, function( dat )
			if not dat then
				print( "Couldn't download addon! Skipping..." )
				callback()
				return
			end

			notification.AddProgress( "wsdl_notify_" .. id, "Downloading " .. dat.title .. " via workshop..." )

			--print( dat.fileid )
			--print( dat.previewid )

			--[[for k,v in pairs( dat ) do
				print( tostring( k ) .. " = " .. tostring( v ) )
			end]]

			steamworks.Download( dat.fileid, true, function( path )
				print( path )
				game.MountGMA( path )
				notification.Kill( "wsdl_notify_" .. id )
				callback()
			end )
		end )
	end

	local function DownloadLoop()
		currentAddon = currentAddon + 1
		print( currentAddon, #table.GetKeys( toDownload ), currentAddon < #toDownload )
		-- If 2 is less than or equal to 3 then this should happen
		-- If 3 is less than or equal to 3 then this should happen
		if currentAddon <= #table.GetKeys( toDownload ) then
			DownloadSteamworksAddon( table.GetKeys( toDownload )[ currentAddon ], DownloadLoop )
		else
			-- Step 5: Inform the user of how great I am
			chat.AddText( "Workshop download done!" )
			print( "In-Game WorkshopDL was created by meharryp (http://steamcommunity.com/id/meharryp)" )
			print( "Get the addon for your server here: http://soon.tm" )
		end
	end

	function GetWorkshopDownloader()
		-- Stage 1: Figure out what's in the workshop collection via the shittest way possible
		timer.Simple( 5, function() -- Don't want it starting straight away
			print( collection:GetString() )
			local strCollection = string.Replace( collection:GetString(), "http://steamcommunity.com/sharedfiles/filedetails/?id=", "" )
			strCollection = string.Replace( strCollection, "https://steamcommunity.com/sharedfiles/filedetails/?id=", "" )

			--print( strCollection )

			local html = vgui.Create( "DHTML" )
			html:SetSize( 0, 0 )
			html:SetPos( 0, 0 )
			html:OpenURL( "http://meharryp.xyz/wsapi.html#endpoint=ISteamRemoteStorage/GetCollectionDetails/v1/&format=json&collectioncount=1&publishedfileids[0]=" .. strCollection )

			-- Stage 2: Extract list from responce
			timer.Simple( 5, function() -- This is the hackiest way of doing it, but it works.
				html:AddFunction( "wsdl", "GetDetails", function( str )
					str = string.Replace( str, [[<html><head></head><body><pre style="word-wrap: break-word; white-space: pre-wrap;">]], "" )
					str = string.Replace( str, [[</pre></body></html>]], "" )

					local res = util.JSONToTable( str )
					--print( str )

					if not res.response then
						print( "Couldn't get a response! Retrying in 90 seconds..." )
						timer.Simple( 90, function()
							GetWorkshopDownloader()
						end )
						return
					end

					-- Stage 3: Add the addons to the toDownload table for later use
					for k,v in pairs( res.response.collectiondetails[ 1 ].children ) do
						toDownload[ v.publishedfileid ] = true
					end

					-- Stage 4: Download the addons
					timer.Simple( 5, function() -- Now we download the addons
						DownloadSteamworksAddon( table.GetKeys( toDownload )[ currentAddon ], DownloadLoop )
					end )
				end )

				-- Step 2a: Why is DHTML:GetHTML() not a function
				html:RunJavascript( "wsdl.GetDetails( document.documentElement.outerHTML );" )
			end )
		end )
	end

	hook.Add( "InitPostEntity", "WDSL_Start", GetWorkshopDownloader )

	-- Extra stage: resource.AddWorkshop overwriting
	-- The toDownload[ key ] = true part will stop duplicate adddons being added.
	net.Receive( "RSWorkshop", function()
		local tab = net.ReadTable()
		for k,v in pairs( tab ) do
			toDownload[ k ] = true
		end
	end )
end
