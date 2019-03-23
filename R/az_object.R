#' Azure Active Directory object
#'
#' Base class representing a directory object in Microsoft Graph.
#'
#' @docType class
#' @section Fields:
#' - `token`: The token used to authenticate with the Graph host.
#' - `tenant`: The Azure Active Directory tenant for this group.
#' - `type`: The type of object: user, group, application or service principal.
#' - `properties`: The group properties.
#' @section Methods:
#' - `new(...)`: Initialize a new group object. Do not call this directly; see 'Initialization' below.
#' - `delete(confirm=TRUE)`: Delete a group. By default, ask for confirmation first.
#' - `update(...)`: Update the group information in Azure Active Directory.
#' - `sync_fields()`: Synchronise the R object with the app data in Azure Active Directory.
#' - `list_group_memberships()`: Return the IDs of all groups this object is a member of.
#' - `list_object_memberships()`: Return the IDs of all groups, administrative units and directory roles this object is a member of.
#'
#' @section Initialization:
#' Objects of this class should not be created directly. Instead, create an object of the appropriate subclass: [az_app], [az_service_principal], [az_user], [az_group].
#'
#' @seealso
#' [ms_graph], [az_app], [az_service_principal], [az_user], [az_group]
#'
#' [Microsoft Graph overview](https://docs.microsoft.com/en-us/graph/overview),
#' [REST API reference](https://docs.microsoft.com/en-us/graph/api/overview?view=graph-rest-beta)
#'
#' @format An R6 object of class `az_object`.
#' @export
az_object <- R6::R6Class("az_object",

public=list(

    token=NULL,
    tenant=NULL,
    type=NULL,

    # app data from server
    properties=NULL,

    initialize=function(token, tenant=NULL, properties=NULL)
    {
        self$token <- token
        self$tenant <- tenant
        self$properties <- properties
    },

    update=function(...)
    {
        op <- file.path(private$get_endpoint(), self$properties$id)
        self$graph_op(op, body=list(...), encode="json", http_verb="PATCH")
        self$properties <- self$graph_op(op)
        self
    },

    sync_fields=function()
    {
        op <- file.path(private$get_endpoint(), self$properties$id)
        self$properties <- self$graph_op(op)
        invisible(self)
    },

    delete=function(confirm=TRUE)
    {
        if(confirm && interactive())
        {
            msg <- sprintf("Do you really want to delete the %s '%s'? (y/N) ",
                           self$type, self$properties$displayName)
            yn <- readline(msg)
            if(tolower(substr(yn, 1, 1)) != "y")
                return(invisible(NULL))
        }

        op <- file.path(private$get_endpoint(), self$properties$id)
        self$graph_op(op, http_verb="DELETE")
        invisible(NULL)
    },

    list_object_memberships=function()
    {
        op <- file.path(private$get_endpoint(), self$properties$id, "getMemberObjects")
        lst <- self$graph_op(op, body=list(securityEnabledOnly=TRUE),
            encode="json", http_verb="POST")

        unlist(get_paged_list(lst, self$token))
    },

    list_group_memberships=function()
    {
        op <- file.path(private$get_endpoint(), self$properties$id, "getMemberGroups")
        lst <- self$graph_op(op, body=list(securityEnabledOnly=TRUE),
            encode="json", http_verb="POST")

        unlist(get_paged_list(lst, self$token))
    },

    graph_op=function(op="", ...)
    {
        call_graph_endpoint(self$token, op, ...)
    },

    print=function(...)
    {
        cat("<Graph directory object '", self$properties$displayName, "'>\n", sep="")
        cat("  directory id:", self$properties$id, "\n")
        invisible(self)
    }
),

private=list(

    get_endpoint=function()
    {
        switch(self$type,
            "user"="users",
            "group"="groups",
            "application"="applications",
            "service principal"="servicePrincipals",
            stop("Unknown directory object type"))
    }
))


get_paged_list <- function(lst, token, next_link_name="@odata.nextLink", value_name="value")
{
    res <- lst[[value_name]]
    while(!is_empty(lst[[next_link_name]]))
    {
        lst <- call_graph_url(token, lst[[next_link_name]])
        res <- c(res, lst[[value_name]])
    }
    res
}

