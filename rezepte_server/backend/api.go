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

// RezeptZutat bla
type RezeptZutat struct {
	RezeptZutatID int     `JSON:"RezeptZutatID"`
	Zutat         string  `JSON:"Zutat"`
	Menge         float64 `JSON:"Menge"`
	Mengeneinheit string  `JSON:"Mengeneinheit"`
	Bemerkung     string  `JSON:"Bemerkung"`
}

// RezeptTeil bla
type RezeptTeil struct {
	RezeptTeilID int           `JSON:"RezeptTeilID"`
	Bezeichnung  string        `JSON:"Bezeichnung"`
	Zutaten      []RezeptZutat `JSON:"Zutaten"`
}

// RezeptDetails is the full data
type RezeptDetails struct {
	RezeptKopf
	Anleitung   string       `JSON:"Anleitung"`
	RezeptTeile []RezeptTeil `JSON:"RezeptTeile"`
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

const rezeptDetailsQuery = `SELECT bezeichnung, anleitung, GROUP_CONCAT(rt.tag) tags
	FROM tbl_rezepte r LEFT JOIN tbl_rezept_tags rt ON r.rezept_id = rt.rezept_id
	WHERE r.rezept_id = ?
	GROUP BY r.rezept_id, bezeichnung`

func (hndlr RezeptDetailsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var rd RezeptDetails
	vars := mux.Vars(r)
	if key, err := strconv.Atoi(vars["key"]); err != nil {
		log.Fatal(err)
	} else {
		rd.RezeptID = key
	}
	row := DB.QueryRow(rezeptDetailsQuery, rd.RezeptID)
	var tags sql.NullString
	if err := row.Scan(&rd.Bezeichnung, &rd.Anleitung, &tags); err != nil {
		log.Fatal(err)
	}
	err := rd.setLinks(hndlr.router)
	if err != nil {
		log.Fatal(err)
	}
	rd.Tags = parseTags(tags)
	if err := readZutaten(&rd); err != nil {
		log.Fatal(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rd)
}

const rezeptZutatenQuery = `SELECT
		rt.rezept_teil_id, IFNULL(rt.bezeichnung, ''),
		rz.rezept_zutat_id, rz.zutat, IFNULL(rz.menge, 0), IFNULL(rz.mengeneinheit, ''), IFNULL(rz.bemerkung, '')
	FROM tbl_rezept_teile rt JOIN tbl_rezept_zutaten rz ON rt.rezept_teil_id = rz.rezept_teil_id
	WHERE rt.rezept_id = ?
	ORDER BY rt.reihenfolge, rz.reihenfolge`

func readZutaten(rd *RezeptDetails) error {
	rows, err := DB.Query(rezeptZutatenQuery, rd.RezeptID)
	if err != nil {
		return err
	}
	defer rows.Close()
	teile := make([]RezeptTeil, 0)
	zutaten := make([]RezeptZutat, 0)
	var rt *RezeptTeil
	for rows.Next() {
		var rz RezeptZutat
		var teilID int
		var bezeichnung string
		if err := rows.Scan(
			&teilID, &bezeichnung,
			&rz.RezeptZutatID, &rz.Zutat, &rz.Menge, &rz.Mengeneinheit, &rz.Bemerkung); err != nil {
			return err
		}
		zutaten = append(zutaten, rz)
		if rt == nil {
			rt = &RezeptTeil{RezeptTeilID: teilID, Bezeichnung: bezeichnung}
		} else if teilID != rt.RezeptTeilID {
			rt.Zutaten = zutaten
			teile = append(teile, *rt)
			rt = &RezeptTeil{RezeptTeilID: teilID, Bezeichnung: bezeichnung}
			zutaten = make([]RezeptZutat, 0)
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	if rt != nil {
		rt.Zutaten = zutaten
		teile = append(teile, *rt)
	}
	rd.RezeptTeile = teile
	return nil
}
