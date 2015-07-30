using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;

using Httpfs.Client.UI;

using Httpfsc.Business.Http;

namespace Httpfs.Client
{
    /// <summary>
    /// Main browser window
    /// </summary>
    public partial class Browser
    {
        #region Fields

        private readonly IHttpFileSystemProxy _proxy;
        private readonly ClientConfig _config;
        private Url _currentPath;

        #endregion

        #region Constructors

        public Browser()
        {
            this.InitializeComponent();

            this._config = new ClientConfig();
            this._proxy = new HttpFileSystemProxy(this._config);

            this.CurrentPath = "/";

            this.FolderListView.MouseDoubleClick += (sender, args) =>
            {
                if (this.FolderListView.SelectedItem == null) return;
                if (this.CurrentPath == "/" && this.FolderListView.SelectedItem.ToString() == "../") return;
                if (this.CurrentPath == "/" && this.FolderListView.SelectedItem.ToString() == "./") return;
                this.RefreshList(this.CurrentPath.Combine(this.FolderListView.SelectedItem.ToString()));
            };

            this.FileListView.MouseDoubleClick += async (sender, args) =>
            {
                if (this.CurrentPath == "/") return;
                if (this.FileListView.SelectedItem == null) return;
                await this.DownloadFile(this.CurrentPath.Combine(this.FileListView.SelectedItem.ToString()));
            };

            this.FileListView.Drop += async (sender, args) =>
            {
                var files = (string[])args.Data.GetData(DataFormats.FileDrop);
                await Task.WhenAll(files.Select(f => this.UploadFile(this.CurrentPath, f)));
                this.RefreshList();
            };

            this.DownloadFilesContextMenuItem.Click += async (sender, args) =>
            {
                await Task.WhenAll(this.FileListView.SelectedItems.Cast<Url>().Select(this.DownloadFile));
                this.RefreshList();
            };

            this.RefreshFolderContextMenuItem.Click += (sender, args) => this.RefreshList();

            this.RefreshFileContextMenuItem.Click += (sender, args) => this.RefreshList();

            this.CreateFolderContextMenuItem.Click += async (sender, args) =>
            {
                await this.CreateFolder();
                this.RefreshList();
            };

            this.CreateEmptyFilerContextMenuItem.Click += async (sender, args) =>
            {
                await this.CreateEmptyFile();
                this.RefreshList();
            };

            this.FileMenuCreateEmptyFile.Click += async (sender, args) =>
            {
                await this.CreateEmptyFile();
                this.RefreshList();
            };

            this.FileMenuCreateFolder.Click += async (sender, args) =>
            {
                await this.CreateFolder();
                this.RefreshList();
            };

            this.DeleteFileContextMenuItem.Click += async (sender, args) =>
            {
                await this.DeleteAllSelectedFiles();
                this.RefreshList();
            };

            this.DeleteFolderContextMenuItem.Click += async (sender, args) =>
            {
                await this.DeleteAllSelectedFolders();
                this.RefreshList();
            };

            this.FileListView.KeyUp += async (sender, args) =>
            {
                if (args.Key == Key.Delete)
                {
                    await this.DeleteAllSelectedFiles();
                    this.RefreshList();
                }
            };

            this.FolderListView.KeyUp += async (sender, args) =>
            {
                if (args.Key == Key.Delete)
                {
                    await this.DeleteAllSelectedFolders();
                    this.RefreshList();
                }
            };

            this.RefreshList();
        }

        #endregion

        #region Properties

        private static Action<HttpStatusCode, string> DefaultHttpErrorHandler
        {
            get
            {
                return (code, description) =>
                {
                    if (code != HttpStatusCode.OK)
                    {
                        MessageBox.Show(description, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                };
            }
        }

        private Url CurrentPath
        {
            get
            {
                return this._currentPath;
            }

            set
            {
                this._currentPath = value;
                this.CurrentPathTextBlock.Text = this._config.LocalRoot.Combine(value).FullPath;
            }
        }

        #endregion

        #region Methods

        private async Task DeleteAllSelectedFolders()
        {
            await Task.WhenAll(this.FolderListView.SelectedItems.Cast<Url>().Select(this.DeleteFolder));
        }

        private async Task DeleteAllSelectedFiles()
        {
            await Task.WhenAll(this.FileListView.SelectedItems.Cast<Url>().Select(this.DeleteFile));
        }

        private async Task DeleteFile(Url path)
        {
            await this._proxy.DeleteFile(this.CurrentPath.Combine(path), DefaultHttpErrorHandler);
        }

        private async Task DeleteFolder(Url path)
        {
            await this._proxy.DeleteDirectory(this.CurrentPath.Combine(path), DefaultHttpErrorHandler);
        }

        private async Task CreateEmptyFile()
        {
            var ans = await InputDialog.Ask("File name?", "Create new file");
            if (string.IsNullOrWhiteSpace(ans))
            {
                return;
            }

            await this._proxy.CreateEmptyFile(this.CurrentPath.Combine(ans), DefaultHttpErrorHandler);
        }

        private async Task CreateFolder()
        {
            var ans = await InputDialog.Ask("Folder name?", "Create new folder");
            if (string.IsNullOrWhiteSpace(ans))
            {
                return;
            }

            await this._proxy.CreateDirectory(this.CurrentPath.Combine(ans), DefaultHttpErrorHandler);
        }

        private async void RefreshList(Url path = null)
        {
            if (path != null)
            {
                this.CurrentPath = path;
            }

            var result = await this._proxy.ListDirectory(this.CurrentPath, DefaultHttpErrorHandler);

            this.FolderListView.ItemsSource = result.Folders.OrderBy(f => f.ToString());
            this.FileListView.ItemsSource = result.Files.OrderBy(f => f.FileName);
        }

        private async Task DownloadFile(Url path)
        {
            var downloadToUrl = this._config.LocalRoot.Combine(path);

            await this._proxy.DownloadFile(path, downloadToUrl, DefaultHttpErrorHandler);
        }

        private async Task UploadFile(Url folder, Url path)
        {
            if (path.IsDirectory) return;

            var to = folder.Combine(path.FileName);
            var file = File.ReadAllText(path, Encoding.Default);

            await this._proxy.UploadFile(to, file, DefaultHttpErrorHandler);
        }

        #endregion
    }
}