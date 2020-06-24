{
  Automatic Armor Progression
  By Isvvc
  Uses mteFunctions
}

unit UserScript;

uses 'lib\mteFunctions';

function HexStrToInt(const str: string): Integer;
begin
  Result := StrToInt('$' + str);
end;

function IndexOfHighestRating(armor: string): Integer;
var
	i, rating, indexOfHighestRating, highestRating: Integer;
	pieces: TJsonObject;
begin
	pieces := armor.A['pieces'];
	indexOfHighestRating := 0;
	highestRating := 0;
	
	for i := 0 to pieces.Count - 1 do begin
		rating := armor.A['pieces'].O[i].I['rating'];
		if rating > highestRating then begin
			indexOfHighestRating := i;
			highestRating := rating;
		end;
	end;
    
	Result := indexOfHighestRating;
end;

function GaussianFunction(a: integer; b, c, x: double): double;
begin
	Result := a*power(2.718281828, -1*( power((x - b), 2) / (2*c*c) ));
end;

function CraftingRecipeForItem(item: IInterface): IInterface;
var
	i: Integer;
	rec, bnam: IInterface;
	edid: String;
begin
	for i := 0 to Pred(ReferencedByCount(item)) do begin
		rec := ReferencedByIndex(item, i);
		if Signature(rec) = 'COBJ' then begin
			bnam := ElementByPath(rec, 'BNAM');
			edid := geev(LinksTo(bnam), 'EDID');
			if not ((edid = 'CraftingSmithingArmorTable') or (edid = 'CraftingSmithingSharpeningWheel')) then begin
				Result := rec;
				exit;
			end;
		end;
	end;
end;

function Initialize: Integer;
var
	lightMaterials: TStringList;
	materialCountTotals{, remainingMaterialsCount, thisItemMaterialCount}: array[0..5] of integer;
	sFiles: String;
	i, j, k, newRating, referenceRating, formID, numArmors, indexOfHighestRating, count: integer;
	level: double;
	f, patchFile, rec, patchRec: IInterface;
	s: String;
	json, armors, armor, item: TJsonObject;
	heavy: bool;
	frm: TForm;
	mInfo: TMemo;
begin
	lightMaterials := TStringList.Create;
	
	// Accept JSON input
	frm := TForm.Create(nil);
	
	frm.Caption := 'Enter JSON for armors';
    frm.Width := 950;
    frm.Height := 600;
    frm.Position := poScreenCenter;
	
	mInfo := TMemo.Create(frm);
	mInfo.Parent := frm;
    mInfo.Align := alClient;
    mInfo.BorderStyle := bsNone;
    mInfo.ScrollBars := ssVertical;
	
	frm.ShowModal;
	
	// Parse the JSON input
	json := TJsonBaseObject.Parse(mInfo.Lines.Text);
	
	// Create patch file
	patchFile := FileByName('Armor Progression.esp');
	AddMessage('ayy lmao');
	if not Assigned(patchFile) then begin
		patchFile := AddNewFileName('Armor Progression.esp');
		SetAuthor(patchFile, 'Isvvc');
	end;
	
	// Load in crafting materials
	//materials.Add('0005ace5'); // Steel ingot
	//materials.Add('000db8a2'); // Dwarven metal ingot
	//materials.Add('0005ad99'); // Orichalcum ingot
	lightMaterials.Add('000db5d2'); // Leather
	lightMaterials.Add('0005ad93'); // Corundum Ingot
	lightMaterials.Add('0005ad9f'); // Refined Moonstone
	lightMaterials.Add('0005ada0'); // Quicksilver Ingot
	lightMaterials.Add('0005ada1'); // Refined Malachite
	lightMaterials.Add('0003ada3'); // Dragon Scales
	
	// File 0 should be Skyrim.esm or game equivalent
	f := FileByIndex(0);
	
	for i := 0 to Pred(lightMaterials.Count) do begin
		formID := HexStrToInt(lightMaterials[i]);
	
		// I'm honestly not 100% sure what the bool at the end here does lol
		rec := RecordByFormID(f, formID, false);
		lightMaterials.Objects[i] := TObject(rec);
		AddMessage(geev(rec, 'EDID'));
	end;
	
	// Load all of the armors from JSON
	armors := json.A['armors'];
	numArmors := armors.Count;
	
	for i := 0 to Pred(numArmors) do begin
		armor := armors.O[i];
		AddMessage(armor['name']);
		
		f := FileByName(armor.S['plugin']);
		//g := GroupBySignature(f, 'ARMO');
		
		// Copy the reference to the patch file
		//AddMasterIfMissing(patchFile, armor.S['plugin']);
		
		// For now, space the armors out from level 6 to level 36 evenly
		level := (i / (numArmors - 1) * 30) + 6;
		AddMessage('Level: ' + FloatToStr(level));
		
		// Calculate the armor's total rating
		newRating := level + 46;
		AddMessage('New rating: ' + FloatToStr(newRating));
		
		// Calculate the total number of crafting materials
		for j := 0 to Pred(lightMaterials.Count) do begin
			count := Round(GaussianFunction(9, (j / (5) * 30) + 6, 2.3, level));
			AddMessage(IntToStr(count) + ' ' +geev(ObjectToElement(lightMaterials.Objects[j]), 'EDID'));
			materialCountTotals[j] := count;
			
			// If this material is 4 or less (but above 0),
			// make sure the previous material is at least 5.
			if ((j > 0) and (count > 0) and (count < 5)) then begin
				AddMessage('j: ' + IntToStr(j));
				if materialCountTotals[j-1] < 4 then
					materialCountTotals[j-1] := 5;
			end;
		end;
		
		//indexOfHighestRating := IndexOfHighestRating(armor);
		//AddMessage('Index of highest armor rating: ' + IntToStr(indexOfHighestRating));
		
		referenceRating := armor['totalRating'];
		for j := 0 to Pred(armor.A['pieces'].Count) do begin
			item := armor.A['pieces'].O[j];
			
			// Find the reference to the piece
			formID := HexStrToInt(item.S['FormID']);
			AddMessage(IntToHex(formID, 8));
			
			rec := RecordByFormID(f, formID, false);
			//AddMessage(geev(rec, 'EDID'));
			
			// Copy the element to the patch file
			AddRequiredElementMasters(rec, patchFile, false);
			patchRec := wbCopyElementToFile(rec, patchFile, false, true);
			AddMessage(geev(patchRec, 'EDID'));
		
			// Calculate this piece's armor rating
			AddMessage(geev(rec, 'EDID') + '. Armor rating: ' + FloatToStr(item['rating'] / referenceRating * newRating));
			seev(patchRec, 'DNAM', item['rating'] / referenceRating * newRating);
			
			// Find the crafting recipe
			rec := CraftingRecipeForItem(rec);
			AddMessage(geev(rec, 'EDID'));
			
			// Update crafting recipe
			
			for k := 0 to Pred(materialCountTotals.Count) do begin
				
			end;
		end;
	end;
	
	lightMaterials.Free;
	frm.Free;
end;

end.