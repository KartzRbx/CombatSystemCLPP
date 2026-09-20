export type FlareKind = "packet" | "query";
export type FlareSide = "Client" | "Server";

export type FlareType =
	| "u8"
	| "u16"
	| "u32"
	| "i8"
	| "i16"
	| "i32"
	| "f32"
	| "f64"
	| "bool"
	| "string"
	| "Vector3"
	| "Vector2"
	| "CFrame"
	| "Color3"
	| "UDim"
	| "UDim2"
	| "BrickColor"
	| "buffer"
	| "Instance"
	| "Player";

export type FlareField = {
	type: FlareType;
	name: string;
};

export type FlarePacket = {
	kind: "packet";
	name: string;
	id: number;
	from: FlareSide;
	reliable: boolean;
	fields: FlareField[];
};

export type FlareQuery = {
	kind: "query";
	name: string;
	id: number;
	request: FlareField[];
	returns: FlareType;
};

export type FlareSchema = {
	name: string;
	sourcePath: string;
	packets: FlarePacket[];
	queries: FlareQuery[];
};

export type FlareEmitResult = {
	headerRel: string;
	headerPath: string;
	header: string;
	luauRel: string;
	luau: string;
};
