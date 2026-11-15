package br.edu.bd2.supermercado.ui;

import java.util.Scanner;

public final class Console {

    private static final Scanner IN = new Scanner(System.in);

    private Console() {
    }

    public static String ler(String rotulo) {
        System.out.print(rotulo + ": ");
        if (!IN.hasNextLine()) {
            System.exit(0);
        }
        return IN.nextLine().trim();
    }

    public static String ler(String rotulo, String atual) {
        String s = ler(rotulo + " [" + atual + "]");
        return s.isEmpty() ? atual : s;
    }

    public static Long lerId(String rotulo) {
        return Long.valueOf(ler(rotulo));
    }

    public static String causa(Throwable e) {
        while (e.getCause() != null) {
            e = e.getCause();
        }
        return e.getMessage();
    }
}
