package bootstrap

import "testing"

func TestResolveCatalogXMLPathConfigured(t *testing.T) {
	path := ResolveCatalogXMLPath("../catalog/testdata/minimal.xml")
	if path == "" {
		t.Fatal("expected configured path to resolve")
	}
}

func TestResolveCatalogXMLPathMissing(t *testing.T) {
	path := ResolveCatalogXMLPath("/does/not/exist/XML_Kompendium_2023.xml")
	if path != "" {
		t.Fatalf("expected empty path, got %q", path)
	}
}
