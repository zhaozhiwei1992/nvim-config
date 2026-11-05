-- jdk.lua —— JDK 常用类型的 FQN 静态表（补 import 用）
-- 为什么需要：符号索引只覆盖项目内的 .java，JDK 类型既不在项目里也没有源码，
--   搜索无法「反查 FQN」；没有这张表，<leader>ci 对 List/Map/Optional 这类高频类型完全失效。
-- 表的生成方式：2026-11-06 用 `javap -q <fqn>` 逐个校验存在性，187 条全部存在（同名类取最常用者，
--   如 Date → java.util.Date）。P2 接 ~/java-src 依赖索引后可弱化。
-- 规则：不含 java.lang（无需 import）；不含需要用全限定名消歧的同名类型（java.sql.Date 等）。
local M = {}

M.known = {
  -- java.util
  ['List'] = 'java.util.List', ['ArrayList'] = 'java.util.ArrayList',
  ['LinkedList'] = 'java.util.LinkedList', ['Vector'] = 'java.util.Vector',
  ['Stack'] = 'java.util.Stack', ['Map'] = 'java.util.Map', ['HashMap'] = 'java.util.HashMap',
  ['LinkedHashMap'] = 'java.util.LinkedHashMap', ['TreeMap'] = 'java.util.TreeMap',
  ['Hashtable'] = 'java.util.Hashtable', ['Set'] = 'java.util.Set',
  ['HashSet'] = 'java.util.HashSet', ['LinkedHashSet'] = 'java.util.LinkedHashSet',
  ['TreeSet'] = 'java.util.TreeSet', ['Collection'] = 'java.util.Collection',
  ['Collections'] = 'java.util.Collections', ['Arrays'] = 'java.util.Arrays',
  ['Objects'] = 'java.util.Objects', ['Optional'] = 'java.util.Optional',
  ['Iterator'] = 'java.util.Iterator', ['ListIterator'] = 'java.util.ListIterator',
  ['Comparator'] = 'java.util.Comparator', ['Date'] = 'java.util.Date',
  ['Calendar'] = 'java.util.Calendar', ['UUID'] = 'java.util.UUID',
  ['Scanner'] = 'java.util.Scanner', ['Random'] = 'java.util.Random',
  ['Locale'] = 'java.util.Locale', ['TimeZone'] = 'java.util.TimeZone',
  ['Queue'] = 'java.util.Queue', ['Deque'] = 'java.util.Deque',
  ['ArrayDeque'] = 'java.util.ArrayDeque', ['PriorityQueue'] = 'java.util.PriorityQueue',
  ['EnumMap'] = 'java.util.EnumMap', ['EnumSet'] = 'java.util.EnumSet',
  ['BitSet'] = 'java.util.BitSet', ['Properties'] = 'java.util.Properties',
  ['StringJoiner'] = 'java.util.StringJoiner', ['StringTokenizer'] = 'java.util.StringTokenizer',
  ['Formatter'] = 'java.util.Formatter', ['SplittableRandom'] = 'java.util.SplittableRandom',
  -- java.util.stream
  ['Stream'] = 'java.util.stream.Stream', ['Collectors'] = 'java.util.stream.Collectors',
  ['IntStream'] = 'java.util.stream.IntStream', ['LongStream'] = 'java.util.stream.LongStream',
  ['DoubleStream'] = 'java.util.stream.DoubleStream',
  -- java.util.function
  ['Function'] = 'java.util.function.Function', ['BiFunction'] = 'java.util.function.BiFunction',
  ['Supplier'] = 'java.util.function.Supplier', ['Consumer'] = 'java.util.function.Consumer',
  ['BiConsumer'] = 'java.util.function.BiConsumer', ['Predicate'] = 'java.util.function.Predicate',
  ['BiPredicate'] = 'java.util.function.BiPredicate',
  ['UnaryOperator'] = 'java.util.function.UnaryOperator',
  ['BinaryOperator'] = 'java.util.function.BinaryOperator',
  -- java.util.regex
  ['Pattern'] = 'java.util.regex.Pattern', ['Matcher'] = 'java.util.regex.Matcher',
  ['PatternSyntaxException'] = 'java.util.regex.PatternSyntaxException',
  -- java.util.concurrent
  ['ExecutorService'] = 'java.util.concurrent.ExecutorService',
  ['Executors'] = 'java.util.concurrent.Executors',
  ['CompletableFuture'] = 'java.util.concurrent.CompletableFuture',
  ['Future'] = 'java.util.concurrent.Future', ['TimeUnit'] = 'java.util.concurrent.TimeUnit',
  ['ConcurrentHashMap'] = 'java.util.concurrent.ConcurrentHashMap',
  ['ConcurrentLinkedQueue'] = 'java.util.concurrent.ConcurrentLinkedQueue',
  ['CopyOnWriteArrayList'] = 'java.util.concurrent.CopyOnWriteArrayList',
  ['CountDownLatch'] = 'java.util.concurrent.CountDownLatch',
  ['Semaphore'] = 'java.util.concurrent.Semaphore',
  ['ThreadPoolExecutor'] = 'java.util.concurrent.ThreadPoolExecutor',
  ['ScheduledExecutorService'] = 'java.util.concurrent.ScheduledExecutorService',
  ['BlockingQueue'] = 'java.util.concurrent.BlockingQueue',
  ['LinkedBlockingQueue'] = 'java.util.concurrent.LinkedBlockingQueue',
  -- java.util.concurrent.atomic
  ['AtomicInteger'] = 'java.util.concurrent.atomic.AtomicInteger',
  ['AtomicLong'] = 'java.util.concurrent.atomic.AtomicLong',
  ['AtomicBoolean'] = 'java.util.concurrent.atomic.AtomicBoolean',
  ['AtomicReference'] = 'java.util.concurrent.atomic.AtomicReference',
  -- java.util.zip
  ['ZipFile'] = 'java.util.zip.ZipFile', ['ZipEntry'] = 'java.util.zip.ZipEntry',
  ['ZipOutputStream'] = 'java.util.zip.ZipOutputStream',
  ['ZipInputStream'] = 'java.util.zip.ZipInputStream',
  ['GZIPOutputStream'] = 'java.util.zip.GZIPOutputStream',
  ['GZIPInputStream'] = 'java.util.zip.GZIPInputStream',
  -- java.util.logging
  ['Logger'] = 'java.util.logging.Logger', ['Level'] = 'java.util.logging.Level',
  -- java.io
  ['File'] = 'java.io.File', ['IOException'] = 'java.io.IOException',
  ['UncheckedIOException'] = 'java.io.UncheckedIOException',
  ['InputStream'] = 'java.io.InputStream', ['OutputStream'] = 'java.io.OutputStream',
  ['Reader'] = 'java.io.Reader', ['Writer'] = 'java.io.Writer',
  ['BufferedReader'] = 'java.io.BufferedReader', ['BufferedWriter'] = 'java.io.BufferedWriter',
  ['InputStreamReader'] = 'java.io.InputStreamReader',
  ['OutputStreamWriter'] = 'java.io.OutputStreamWriter', ['FileReader'] = 'java.io.FileReader',
  ['FileWriter'] = 'java.io.FileWriter', ['FileInputStream'] = 'java.io.FileInputStream',
  ['FileOutputStream'] = 'java.io.FileOutputStream', ['PrintStream'] = 'java.io.PrintStream',
  ['PrintWriter'] = 'java.io.PrintWriter', ['RandomAccessFile'] = 'java.io.RandomAccessFile',
  ['Serializable'] = 'java.io.Serializable', ['Externalizable'] = 'java.io.Externalizable',
  ['FileFilter'] = 'java.io.FileFilter', ['FilenameFilter'] = 'java.io.FilenameFilter',
  ['Closeable'] = 'java.io.Closeable', ['Flushable'] = 'java.io.Flushable',
  ['UnsupportedEncodingException'] = 'java.io.UnsupportedEncodingException',
  ['EOFException'] = 'java.io.EOFException',
  ['FileNotFoundException'] = 'java.io.FileNotFoundException',
  -- java.nio.file
  ['Path'] = 'java.nio.file.Path', ['Paths'] = 'java.nio.file.Paths',
  ['Files'] = 'java.nio.file.Files', ['StandardCopyOption'] = 'java.nio.file.StandardCopyOption',
  ['WatchService'] = 'java.nio.file.WatchService',
  -- java.nio.charset
  ['StandardCharsets'] = 'java.nio.charset.StandardCharsets',
  ['Charset'] = 'java.nio.charset.Charset',
  -- java.nio
  ['ByteBuffer'] = 'java.nio.ByteBuffer', ['CharBuffer'] = 'java.nio.CharBuffer',
  ['IntBuffer'] = 'java.nio.IntBuffer', ['LongBuffer'] = 'java.nio.LongBuffer',
  ['DoubleBuffer'] = 'java.nio.DoubleBuffer', ['FloatBuffer'] = 'java.nio.FloatBuffer',
  ['ShortBuffer'] = 'java.nio.ShortBuffer', ['MappedByteBuffer'] = 'java.nio.MappedByteBuffer',
  ['ByteOrder'] = 'java.nio.ByteOrder',
  -- java.math
  ['BigDecimal'] = 'java.math.BigDecimal', ['BigInteger'] = 'java.math.BigInteger',
  ['MathContext'] = 'java.math.MathContext', ['RoundingMode'] = 'java.math.RoundingMode',
  -- java.time
  ['LocalDate'] = 'java.time.LocalDate', ['LocalDateTime'] = 'java.time.LocalDateTime',
  ['LocalTime'] = 'java.time.LocalTime', ['Duration'] = 'java.time.Duration',
  ['Instant'] = 'java.time.Instant', ['Period'] = 'java.time.Period',
  ['ZoneId'] = 'java.time.ZoneId', ['ZonedDateTime'] = 'java.time.ZonedDateTime',
  ['OffsetDateTime'] = 'java.time.OffsetDateTime', ['DayOfWeek'] = 'java.time.DayOfWeek',
  ['Month'] = 'java.time.Month', ['Clock'] = 'java.time.Clock',
  -- java.time.format
  ['DateTimeFormatter'] = 'java.time.format.DateTimeFormatter',
  -- java.text
  ['SimpleDateFormat'] = 'java.text.SimpleDateFormat', ['DateFormat'] = 'java.text.DateFormat',
  ['DecimalFormat'] = 'java.text.DecimalFormat', ['NumberFormat'] = 'java.text.NumberFormat',
  ['MessageFormat'] = 'java.text.MessageFormat', ['ParseException'] = 'java.text.ParseException',
  ['Collator'] = 'java.text.Collator',
  -- java.net
  ['URI'] = 'java.net.URI', ['URL'] = 'java.net.URL',
  ['HttpURLConnection'] = 'java.net.HttpURLConnection', ['InetAddress'] = 'java.net.InetAddress',
  ['URLEncoder'] = 'java.net.URLEncoder', ['URLDecoder'] = 'java.net.URLDecoder',
  ['Socket'] = 'java.net.Socket', ['ServerSocket'] = 'java.net.ServerSocket',
  ['UnknownHostException'] = 'java.net.UnknownHostException',
  ['MalformedURLException'] = 'java.net.MalformedURLException',
  ['InetSocketAddress'] = 'java.net.InetSocketAddress',
  -- java.net.http
  ['HttpClient'] = 'java.net.http.HttpClient', ['HttpRequest'] = 'java.net.http.HttpRequest',
  ['HttpResponse'] = 'java.net.http.HttpResponse',
  -- java.sql
  ['Connection'] = 'java.sql.Connection', ['Statement'] = 'java.sql.Statement',
  ['PreparedStatement'] = 'java.sql.PreparedStatement',
  ['CallableStatement'] = 'java.sql.CallableStatement', ['ResultSet'] = 'java.sql.ResultSet',
  ['SQLException'] = 'java.sql.SQLException', ['DriverManager'] = 'java.sql.DriverManager',
  ['Timestamp'] = 'java.sql.Timestamp', ['Time'] = 'java.sql.Time',
  ['BatchUpdateException'] = 'java.sql.BatchUpdateException',
  -- javax.sql
  ['DataSource'] = 'javax.sql.DataSource',
  -- java.security
  ['MessageDigest'] = 'java.security.MessageDigest',
  ['NoSuchAlgorithmException'] = 'java.security.NoSuchAlgorithmException',
  ['SecureRandom'] = 'java.security.SecureRandom', ['KeyStore'] = 'java.security.KeyStore',
  -- java.lang.reflect
  ['Method'] = 'java.lang.reflect.Method', ['Field'] = 'java.lang.reflect.Field',
  ['Constructor'] = 'java.lang.reflect.Constructor', ['Array'] = 'java.lang.reflect.Array',
  ['InvocationTargetException'] = 'java.lang.reflect.InvocationTargetException',
  ['Modifier'] = 'java.lang.reflect.Modifier', ['Proxy'] = 'java.lang.reflect.Proxy',}

--- 按简单名查 JDK 类型 FQN
---@param name string
---@return string|nil
function M.lookup(name)
  return M.known[name]
end

return M
