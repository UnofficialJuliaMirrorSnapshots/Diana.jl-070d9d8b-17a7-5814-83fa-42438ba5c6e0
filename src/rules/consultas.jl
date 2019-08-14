
struct getdeep <:Rule
	enter
	leave
	valordeep
	function getdeep()
		valor=1
		nivel=1
		function valordeep()
			return valor
		end
		function enter(node::Node)
			if (node.kind=="Field")
				if (typeof(node.selectionSet)<:Node)
					nivel = nivel+1
					if(nivel>valor)
						valor = nivel
					end
				end
			end
		end
		function leave(node::Node)
			if (node.kind=="Field")
				if (typeof(node.selectionSet)<:Node)
					nivel = nivel-1
				end
			end
		end
		new(enter,leave,valordeep)
	end
end

struct NotExtensionOnOperation <:Rule
	enter
	leave
	function NotExtensionOnOperation()
		function enter(node::Node)
			if (node.kind== "TypeExtensionDefinition")
				throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"GraphQL cannot execute a request containing a TypeExtensionDefinition.\"}]}"))
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end

struct NotTypeOnOperation <:Rule
	enter
	leave
	function NotTypeOnOperation()
		function enter(node::Node)
			if (node.kind== "ObjectTypeDefinition")
				return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"GraphQL cannot execute a request containing a ObjectTypeDefinition.\"}]}"))
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end

struct NotSchemaOnOperation <:Rule
	enter
	leave
	function NotSchemaOnOperation()
		function enter(node::Node)
			if (node.kind== "SchemaDefinition")
				return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"GraphQL cannot execute a request containing a SchemaDefinition.\"}]}"))
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end



struct FragmentSubscription <:Rule
	enter
	leave
	function FragmentSubscription()
		function enter(node::Node)
			if (node.kind== "FragmentDefinition")
				if (node.typeCondition[2].name.value == "Subscription")
					if (length(node.selectionSet.selections)>1)
						return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"subscription must select only one top level field\"}]}"))
					end
				end
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end


struct FragmentNames <:Rule
	enter
	leave
	function FragmentNames()
		nombres=[]
		function enter(node::Node)
			if (node.kind== "FragmentDefinition")
				valor= node.name.value
				if(valor in nombres)
					return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"There can only be one fragment named \'$(valor)\'.\"}]}"))
				else
					push!(nombres,valor)
				end
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end

struct OperationNames <:Rule
	enter
	leave
	function OperationNames()
		nombres=[]
		function enter(node::Node)
			if (node.kind== "OperationDefinition")
				valor= node.name
				if (typeof(valor)<: Name)
					valor= valor.value
					if(valor in nombres)
						return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"There can only be one operation named \'$(valor)\'.\"}]}"))
					else
						push!(nombres,valor)
					end
				end
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end

struct OperationAnonymous <:Rule
	enter
	leave
	function OperationAnonymous()
		n_operation = 0
		anonimo= false
		function enter(node::Node)
			if (node.kind== "OperationDefinition")
				valor = node.name
				n_operation=n_operation+1
				if !(typeof(valor)<: Name)
					anonimo=true
				end
				if ((anonimo== true) & (n_operation>1))
					return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"This anonymous operation must be the only defined operation.\"}]}"))
				end
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end

struct SubscriptionFields <:Rule
	enter
	leave
	function SubscriptionFields()
		function enter(node::Node)
			if (node.kind== "OperationDefinition")
				if (node.operation == "subscription")
					if (length(node.selectionSet.selections)>1)
						return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"subscription must select only one top level field.\"}]}"))
					end
				end
			end
		end
		function leave(node::Node)

		end
		new(enter,leave)
	end
end


struct FragmentUnknowNotUsed <:Rule
	enter
	leave
	function FragmentUnknowNotUsed()
		nombres=[]
		usados=[]
		yausados=[]
		texto = ""
		function enter(node::Node)
			if (node.kind== "FragmentSpread") #usados
				nombre = node.name.value
				if( nombre in nombres)
					deleteat!(nombres,findfirst(isequal(nombre), nombres))
				else
					if !(nombre in yausados)
					push!(usados,nombre)
					end
				end
			end
			if (node.kind== "FragmentDefinition")
				valor= node.name.value
				if(valor in usados)
					deleteat!(usados,findfirst(isequal(valor), usados))
					if(!(valor in yausados))
					    push!(yausados,valor)
					end
				else
					push!(nombres,valor)
				end
			end
		end
		function leave(node::Node)
			if (node.kind=="Document")
				if (length(nombres)>0)
				  for n in nombres
				      texto=texto*" "*n
				  end
				  return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"Fragment $(texto) is not used.\"}]}"))
				end
				if (length(usados)>0)
				    for n in usados
				      texto=texto*" "*n
				    end
 				  return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"Unknown fragment $(texto).\"}]}"))
				end
			end
		end
		new(enter,leave)
	end
end


struct FragmentCycles <:Rule
	enter
	leave
	function FragmentCycles()
		nombrescycles=[]
		usadoscycles=[]
		inicio = ""
		traza = ""
		leerspread =false
		function enter(node::Node)
			if (node.kind== "FragmentSpread") #usadoscycles
				if (leerspread == true)
				nombre = node.name.value
				push!(usadoscycles,nombre)
				end
			end

			if (node.kind== "FragmentDefinition")
				leerspread =true
				valor= node.name.value
				push!(nombrescycles,valor)
			end
		end

		function leave(node::Node)
			if (node.kind== "FragmentDefinition")
				leerspread =false
			end
			if (node.kind=="Document")
				if (length(nombrescycles)>0)
				if (length(nombrescycles)==length(usadoscycles))
					inicio = nombrescycles[1]
					for l in nombrescycles[2:end]
					    traza=traza*" "*l
					end
				    return throw(GraphQLError("{\"data\": null,\"errors\": [{\"message\": \"Cannot spread fragment $(inicio) within itself via $(traza).\"}]}"))
				end
				end
			end
		end
		new(enter,leave)
	end
end
