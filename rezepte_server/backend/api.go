package backend

import (
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

// RezeptKopf represents the data sufficient for a list display
type RezeptKopf struct {
	APILink     string   `JSON:"APILink"`
	UILink      string   `JSON:"UILink"`
	RezeptID    int      `JSON:"RezeptID"`
	Bezeichnung string   `JSON:"Bezeichnung"`
	Tags        []string `JSON:"Tags"`
}

// RezeptDetails is the full data
type RezeptDetails struct {
	RezeptKopf
	Anleitung string `JSON:"Anleitung"`
}

// RezepteHandler serves a list of RezeptKopf as JSON
type RezepteHandler struct {
	router *mux.Router
}

// RezeptDetailsHandler serves RezeptDetails as JSON
type RezeptDetailsHandler struct {
	router *mux.Router
}

func getLink(router *mux.Router, routeName string, key int) (string, error) {
	apiRoute := router.Get(routeName)
	if apiRoute == nil {
		return "", errors.New("Route " + routeName + " nicht definiert")
	}
	url, err := apiRoute.URL("key", strconv.Itoa(key))
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

func (rk *RezeptKopf) setLinks(router *mux.Router) error {
	link, err := getLink(router, "RezeptAPI", rk.RezeptID)
	if err != nil {
		log.Fatal(err)
		return err
	}
	rk.APILink = link
	link, err = getLink(router, "RezeptUI", rk.RezeptID)
	if err != nil {
		log.Fatal(err)
		return err
	}
	rk.UILink = link
	return nil
}

func parseTags(tagString sql.NullString) []string {
	if tagString.Valid {
		return strings.Split(tagString.String, ",")
	}
	return []string{}
}

const rezepteQuery = `SELECT r.rezept_id, bezeichnung, GROUP_CONCAT(rt.tag) tags
	FROM tbl_rezepte r LEFT JOIN tbl_rezept_tags rt ON r.rezept_id = rt.rezept_id
	GROUP BY r.rezept_id, bezeichnung
	ORDER BY bezeichnung`

func (hndlr RezepteHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	rows, err := DB.Query(rezepteQuery)
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()
	rezepte := make([]RezeptKopf, 0)
	for rows.Next() {
		var rk RezeptKopf
		var tags sql.NullString
		if err := rows.Scan(&rk.RezeptID, &rk.Bezeichnung, &tags); err != nil {
			log.Fatal(err)
		}
		err := rk.setLinks(hndlr.router)
		if err != nil {
			log.Fatal(err)
		}
		rk.Tags = parseTags(tags)
		rezepte = append(rezepte, rk)
	}
	if err := rows.Err(); err != nil {
		log.Fatal(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rezepte)
}

const rezeptDetailsQuery = `SELECT r.rezept_id, bezeichnung, anleitung, GROUP_CONCAT(rt.tag) tags
	FROM tbl_rezepte r LEFT JOIN tbl_rezept_tags rt ON r.rezept_id = rt.rezept_id
	WHERE r.rezept_id = ?
	GROUP BY r.rezept_id, bezeichnung`

func (hndlr RezeptDetailsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["key"]
	row := DB.QueryRow(rezeptDetailsQuery, key)
	var rd RezeptDetails
	var tags sql.NullString
	if err := row.Scan(&rd.RezeptID, &rd.Bezeichnung, &rd.Anleitung, &tags); err != nil {
		log.Fatal(err)
	}
	err := rd.setLinks(hndlr.router)
	if err != nil {
		log.Fatal(err)
	}
	rd.Tags = parseTags(tags)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rd)
}
