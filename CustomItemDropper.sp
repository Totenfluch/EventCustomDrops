#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <store>
#include <EventItemsSpawner>
#include <multicolors>

#pragma newdecls required

enum DropItem {
	diId, 
	diStoreId, 
	String:diName[128], 
	String:diModel[128], 
	String:diAnimation[64], 
	float:diDroprate, 
}

int g_iLoadedDrops = 0;
int g_eCustomItemDrops[2048][DropItem];

public Plugin myinfo = 
{
	name = "CustomItemDropper", 
	author = PLUGIN_AUTHOR, 
	description = "dropps Custom items for zephstore", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	RegAdminCmd("sm_testarray", testArray, ADMFLAG_ROOT, "tests if items are correctly loaded");
}

public Action testArray(int client, int args) {
	for (int x = 0; x < g_iLoadedDrops; x++) {
		PrintToConsole(client, "%d :: %i: %s %s %s", x, g_eCustomItemDrops[x][diStoreId], g_eCustomItemDrops[x][diName], g_eCustomItemDrops[x][diModel], g_eCustomItemDrops[x][diAnimation]);
	}
	return Plugin_Handled;
}

public bool loadAllDrops() {
	clearAllDrops();
	
	KeyValues kv = new KeyValues("CustomItemDrops");
	kv.ImportFromFile("addons/sourcemod/configs/CustomItemDropperConfig.txt");
	
	if (!kv.GotoFirstSubKey())
		return false;
	
	char buffer[128];
	do
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		strcopy(g_eCustomItemDrops[g_iLoadedDrops][diName], 128, buffer);
		
		char tempVars[128];
		kv.GetString("model", tempVars, 128, "");
		strcopy(g_eCustomItemDrops[g_iLoadedDrops][diModel], 128, tempVars);
		if (StrEqual(g_eCustomItemDrops[g_iLoadedDrops][diModel], "")) {
			PrintToServer("%s has an invalid model", g_eCustomItemDrops[g_iLoadedDrops][diName]);
			continue;
		} else {
			PrecacheModel(tempVars, true);
		}
		
		kv.GetString("animation", tempVars, 64, "");
		strcopy(g_eCustomItemDrops[g_iLoadedDrops][diAnimation], 64, tempVars);
		
		g_eCustomItemDrops[g_iLoadedDrops][diDroprate] = kv.GetFloat("droprate", 0.0);
		
		g_eCustomItemDrops[g_iLoadedDrops][diId] = g_iLoadedDrops;
		g_iLoadedDrops++;
		
	} while (kv.GotoNextKey());
	
	delete kv;
	return true;
}

public void clearAllDrops() {
	g_iLoadedDrops = 0;
	for (int i = 0; i < 2048; i++) {
		strcopy(g_eCustomItemDrops[i][diName], 128, "");
		strcopy(g_eCustomItemDrops[i][diModel], 128, "");
		strcopy(g_eCustomItemDrops[i][diAnimation], 64, "");
	}
}

public void OnConfigsExecuted() {
	CreateTimer(10.0, postLoadItems);
	loadAllDrops();
	loadItems();
}

public Action postLoadItems(Handle Timer) {
	loadAllDrops();
	loadItems();
}

public void loadItems() {
	for (int i = 0; i < g_iLoadedDrops; i++) {
		PrintToServer(g_eCustomItemDrops[i][diName]);
	}
	for (int i = 0; i < STORE_MAX_ITEMS; i++) {
		int ti[Store_Item];
		Store_GetItem(i, ti);
		for (int x = 0; x < g_iLoadedDrops; x++) {
			if (StrEqual(ti[szName], g_eCustomItemDrops[x][diName]) && !StrEqual(ti[szName], "")) {
				g_eCustomItemDrops[x][diStoreId] = i;
				PrintToServer("%i: %s %s %s", g_eCustomItemDrops[x][diStoreId], ti[szName], g_eCustomItemDrops[x][diModel], g_eCustomItemDrops[x][diAnimation]);
				break;
			}
		}
	}
}

public void itemspawner_OnItemPickupBasic(int client, float x, float y, float z) {
	bool drop = false;
	for (int i = 0; i < g_iLoadedDrops; i++) {
		float chance = GetRandomFloat(0.0, 100.0);
		if (chance <= g_eCustomItemDrops[i][diDroprate]) {
			if (!Store_HasClientItem(client, g_eCustomItemDrops[i][diStoreId])) {
				if (!StrEqual(g_eCustomItemDrops[i][diModel], "")) {
					
					int prop = CreateEntityByName("prop_dynamic_override");
					if (prop != -1) {
						DispatchKeyValue(prop, "model", g_eCustomItemDrops[i][diModel]);
						DispatchKeyValue(prop, "spawnflags", "256");
						DispatchKeyValue(prop, "solid", "0");
						DispatchSpawn(prop);
						AcceptEntityInput(prop, "TurnOn", prop, prop, 0);
						float origin[3];
						origin[0] = x;
						origin[1] = y;
						origin[2] = z;
						float clientPos[3];
						GetClientAbsOrigin(client, clientPos);
						float angles[3];
						GetClientAbsAngles(client, angles);
						float distX = clientPos[0] - origin[0];
						float distY = clientPos[1] - origin[1];
						angles[1] = (ArcTangent2(distY, distX) * 180) / 3.14;
						TeleportEntity(prop, origin, angles, NULL_VECTOR);
						SetVariantString(g_eCustomItemDrops[i][diAnimation]);
						AcceptEntityInput(prop, "SetAnimation");
						CreateTimer(5.0, killProp, EntIndexToEntRef(prop));
					}
				}
				CPrintToChat(client, "{darkred}[{green}GGC{darkred}]{green}You have received the Pet {darkred}%s {green}!!", g_eCustomItemDrops[i][diName]);
				Store_GiveItem(client, g_eCustomItemDrops[i][diStoreId], 1, 0, 10);
			}
			break;
		}
	}
}

public Action killProp(Handle Timer, any data) {
	int entity = EntRefToEntIndex(data);
	if (IsValidEntity(entity)) {
		AcceptEntityInput(entity, "kill");
	}
}
