package backend

import (
	"net/http"

	"github.com/gorilla/mux"
)

func spaHandler(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "../assets/index.html")
}

// NewRouter returns the URL router to use by the backend
func NewRouter() *mux.Router {
	router := mux.NewRouter().StrictSlash(true)
	router.PathPrefix("/assets/").Handler(http.StripPrefix("/assets/", http.FileServer(http.Dir("../assets"))))
	router.Handle("/api/rezepte", RezepteHandler{router: router}).Methods("GET").Name("RezepteAPI")
	router.Handle("/api/rezepte/{key}", RezeptDetailsHandler{router: router}).Methods("GET").Name("RezeptAPI")
	router.HandleFunc("/rezepte/{key}", spaHandler).Methods("GET").Name("RezeptUI")
	router.HandleFunc("/", spaHandler).Methods("GET").Name("RezepteUi")
	return router
}

// url, err := r.Get("article").URL("category", "technology", "id", "42")
