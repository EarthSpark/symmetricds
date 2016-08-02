import java.sql.*;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;


public class psql
{
  public static void main (String args[])
  {
    try {
      Class.forName("org.postgresql.Driver");
    } catch (ClassNotFoundException e) {
      error("Could not load PostgreSQL driver: " + e);
      return;
    }

    String url = System.getenv("JDBC_URL");
    String user = System.getenv("JDBC_USER");
    String password = System.getenv("JDBC_PASSWORD");

    Connection conn = null;
    try {
      conn = DriverManager.getConnection(url, user, password);
    } catch (SQLException e) {
      error("Could not connect to database (" + url + "): " + e);
      return;
    }

    try {
      Statement stmt = null;
      stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery(args[0]);
      rs.next();
      System.out.println(rs.getInt(1));
      stmt.close();
      conn.close();
    } catch (SQLException e) {
      error("Could execute statement: " + e);
      return;
    }
  }

  private static void error(String message)
  {
    System.err.println("ERROR: " + message);
    System.exit(1);
  }

}
