using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

[assembly: DefaultDllImportSearchPaths(DllImportSearchPath.System32)]

namespace ACROptimal.Experimental {
    // SQLite supplied by Windows 10/11. No downloaded DLL or Python runtime.
    public sealed class Database : IDisposable {
        private IntPtr db;
        private const string Library = "winsqlite3.dll";
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] name, out IntPtr db, int flags, IntPtr vfs);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close_v2(IntPtr db);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_errmsg(IntPtr db);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int length, out IntPtr stmt, out IntPtr tail);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr stmt);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr stmt);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_bind_null(IntPtr stmt,int index);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_bind_int64(IntPtr stmt,int index,long value);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_bind_double(IntPtr stmt,int index,double value);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_bind_text(IntPtr stmt,int index,byte[] value,int length,IntPtr destructor);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_column_count(IntPtr stmt);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_name(IntPtr stmt,int column);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_column_type(IntPtr stmt,int column);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern long sqlite3_column_int64(IntPtr stmt,int column);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern double sqlite3_column_double(IntPtr stmt,int column);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr stmt,int column);
        [DllImport(Library, CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_column_bytes(IntPtr stmt,int column);
        static byte[] Utf8(string text) { return Encoding.UTF8.GetBytes(text + "\0"); }
        static string Text(IntPtr ptr, int length) {
            if (ptr == IntPtr.Zero) return "";
            byte[] bytes = new byte[length]; Marshal.Copy(ptr,bytes,0,length);
            return Encoding.UTF8.GetString(bytes);
        }
        static string CString(IntPtr ptr) {
            if (ptr == IntPtr.Zero) return "";
            int length=0; while (Marshal.ReadByte(ptr,length)!=0) length++;
            return Text(ptr,length);
        }
        void Check(int rc) { if (rc!=0) throw new InvalidOperationException("SQLite " + rc + ": " + CString(sqlite3_errmsg(db))); }
        public Database(string path) {
            int rc=sqlite3_open_v2(Utf8(path),out db,6,IntPtr.Zero);
            if (rc!=0) { string message=CString(sqlite3_errmsg(db)); Dispose(); throw new InvalidOperationException(message); }
        }
        IntPtr Prepare(string sql, object[] parameters) {
            IntPtr statement,tail; byte[] bytes=Utf8(sql);
            Check(sqlite3_prepare_v2(db,bytes,bytes.Length,out statement,out tail));
            if (statement==IntPtr.Zero) throw new InvalidOperationException("Empty SQL statement");
            try {
                for (int i=0;i<parameters.Length;i++) {
                    object value=parameters[i]; int rc;
                    if (value==null || value==DBNull.Value) rc=sqlite3_bind_null(statement,i+1);
                    else if (value is double || value is float || value is decimal) rc=sqlite3_bind_double(statement,i+1,Convert.ToDouble(value));
                    else if (value is int || value is long || value is bool) rc=sqlite3_bind_int64(statement,i+1,Convert.ToInt64(value));
                    else { byte[] text=Utf8(Convert.ToString(value)); rc=sqlite3_bind_text(statement,i+1,text,text.Length-1,new IntPtr(-1)); }
                    Check(rc);
                }
                return statement;
            } catch { sqlite3_finalize(statement); throw; }
        }
        public void Exec(string sql, object[] parameters) {
            IntPtr statement=Prepare(sql,parameters);
            try { int rc=sqlite3_step(statement); if (rc!=101 && rc!=100) Check(rc); }
            finally { sqlite3_finalize(statement); }
        }
        public List<Dictionary<string,object>> Query(string sql, object[] parameters) {
            IntPtr statement=Prepare(sql,parameters);
            var rows=new List<Dictionary<string,object>>();
            try {
                int rc;
                while ((rc=sqlite3_step(statement))==100) {
                    var row=new Dictionary<string,object>();
                    for(int i=0;i<sqlite3_column_count(statement);i++) {
                        int type=sqlite3_column_type(statement,i); object value=null;
                        if (type==1) value=sqlite3_column_int64(statement,i);
                        else if (type==2) value=sqlite3_column_double(statement,i);
                        else if (type==3) value=Text(sqlite3_column_text(statement,i),sqlite3_column_bytes(statement,i));
                        else if (type!=5) throw new InvalidOperationException("Unsupported SQLite column type");
                        row[CString(sqlite3_column_name(statement,i))]=value;
                    }
                    rows.Add(row);
                }
                if (rc!=101) Check(rc);
                return rows;
            } finally { sqlite3_finalize(statement); }
        }
        public void Dispose() { if(db!=IntPtr.Zero) { sqlite3_close_v2(db); db=IntPtr.Zero; } }
    }
}
